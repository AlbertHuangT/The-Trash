import * as FileSystem from 'expo-file-system';

import knowledgeRows from '../../assets/trash_knowledge.json';

const edgeFunctionUrl = process.env.EXPO_PUBLIC_SUPABASE_EDGE_FUNCTION_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

const CONFIDENCE_THRESHOLD = 0.1;
const SEARCH_CHUNK_SIZE = 64;

const CATEGORY_MAP = {
  recycle: '可回收',
  recyclable: '可回收',
  compost: '湿垃圾',
  compostable: '湿垃圾',
  landfill: '干垃圾',
  hazardous: '有害垃圾',
  ignore: '未识别'
};

const TIP_MAP = {
  可回收: '倒空液体并冲洗后投放，可提升回收效率。',
  湿垃圾: '尽量去除塑料包装后投放到湿垃圾桶。',
  干垃圾: '无法回收或堆肥的残余垃圾请投放干垃圾。',
  有害垃圾: '请勿混投，建议投放到有害垃圾专用回收点。',
  未识别: '请尽量贴近拍摄，并保证光线充足。'
};

const fallbackResult = (message = '当前无法完成智能识别，请稍后重试。') => ({
  id: String(Date.now()),
  item: '识别失败',
  category: '未识别',
  confidence: 0,
  timestamp: new Date().toISOString(),
  tips: [message],
  source: 'fallback'
});

const normalizeCategory = (value) => {
  const raw = String(value ?? '').trim();
  if (!raw) return '未识别';
  const lower = raw.toLowerCase();
  return CATEGORY_MAP[lower] ?? raw;
};

const ensureTips = (category, payloadTips = []) => {
  const unique = new Set();
  const tips = [];
  payloadTips.forEach((tip) => {
    const normalized = String(tip ?? '').trim();
    if (!normalized || unique.has(normalized)) return;
    unique.add(normalized);
    tips.push(normalized);
  });
  if (tips.length) return tips;
  return [TIP_MAP[category] ?? TIP_MAP.未识别];
};

const toBase64 = async (photo) => {
  if (!photo?.path && !photo?.uri) {
    return null;
  }
  const path = photo.path ?? photo.uri;
  const uri = path.startsWith('file://') ? path : `file://${path}`;
  return FileSystem.readAsStringAsync(uri, {
    encoding: FileSystem.EncodingType.Base64
  });
};

const parseEmbedding = (payload) => {
  const candidates = [
    payload?.embedding,
    payload?.image_embedding,
    payload?.imageEmbedding,
    payload?.features,
    payload?.vector
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate) && candidate.length > 0) {
      return candidate.map((value) => Number(value)).filter(Number.isFinite);
    }
  }
  return null;
};

const dot = (a, b) => {
  let sum = 0;
  for (let idx = 0; idx < a.length; idx += 1) {
    sum += a[idx] * b[idx];
  }
  return sum;
};

const toNormalizedVector = (vector) => {
  if (!Array.isArray(vector) || vector.length === 0) return null;
  const numeric = vector.map((value) => Number(value)).filter(Number.isFinite);
  if (!numeric.length) return null;
  let sumSquare = 0;
  for (let idx = 0; idx < numeric.length; idx += 1) {
    sumSquare += numeric[idx] * numeric[idx];
  }
  const norm = Math.sqrt(sumSquare);
  if (!Number.isFinite(norm) || norm < 1e-8) return null;
  const normalized = new Float32Array(numeric.length);
  for (let idx = 0; idx < numeric.length; idx += 1) {
    normalized[idx] = numeric[idx] / norm;
  }
  return normalized;
};

const alignAndNormalize = (vector, targetDimension) => {
  const normalized = toNormalizedVector(vector);
  if (!normalized) return null;
  if (!targetDimension || normalized.length === targetDimension)
    return normalized;
  if (normalized.length > targetDimension) {
    return normalized.slice(0, targetDimension);
  }
  const padded = new Float32Array(targetDimension);
  padded.set(normalized);
  return toNormalizedVector(Array.from(padded));
};

const yieldToEventLoop = () =>
  new Promise((resolve) => {
    setTimeout(resolve, 0);
  });

class ClassifierService {
  constructor() {
    this.ready = false;
    this.warmed = false;
    this.loading = false;
    this.knowledgeBase = [];
    this.dimension = 0;
    this.initializationError = null;
    this._initPromise = null;
  }

  getStatus() {
    return {
      ready: this.ready,
      warmed: this.warmed,
      loading: this.loading,
      knowledgeCount: this.knowledgeBase.length,
      dimension: this.dimension,
      initializationError: this.initializationError
    };
  }

  async ensureReady() {
    if (this.ready) return this.getStatus();
    if (this._initPromise) return this._initPromise;

    this.loading = true;
    this._initPromise = this.initialize()
      .then(() => this.getStatus())
      .finally(() => {
        this.loading = false;
        this._initPromise = null;
      });
    return this._initPromise;
  }

  async initialize() {
    try {
      const parsed = knowledgeRows;
      if (!Array.isArray(parsed) || !parsed.length) {
        throw new Error('知识库为空');
      }

      const normalizedRows = [];
      for (let index = 0; index < parsed.length; index += 1) {
        const row = parsed[index];
        const normalizedEmbedding = toNormalizedVector(row?.embedding);
        if (!normalizedEmbedding) continue;
        normalizedRows.push({
          id: `${row?.label ?? 'item'}-${index}`,
          label: row?.label ?? 'Unknown Item',
          category: normalizeCategory(row?.category ?? '未识别'),
          embedding: normalizedEmbedding
        });
      }

      if (!normalizedRows.length) {
        throw new Error('知识库向量归一化失败');
      }

      this.dimension = normalizedRows[0].embedding.length;
      this.knowledgeBase = normalizedRows.filter(
        (item) => item.embedding.length === this.dimension
      );
      this.ready = true;
      this.initializationError = null;
    } catch (error) {
      this.ready = false;
      this.initializationError =
        error instanceof Error ? error.message : '初始化失败';
      console.warn('[classifier] initialize failed', error);
      throw error;
    }
  }

  async warmup() {
    await this.ensureReady();
    if (this.warmed) return;
    const sample = this.knowledgeBase[0]?.embedding;
    if (sample) {
      await this.findBestMatch(Array.from(sample));
    }
    this.warmed = true;
  }

  async classify(photo) {
    await this.warmup();

    let remotePayload = null;
    try {
      remotePayload = await this.classifyWithEdge(photo);
    } catch (error) {
      console.warn('[classifier] edge classify failed', error);
    }

    if (remotePayload?.embedding?.length) {
      const localMatch = await this.findBestMatch(remotePayload.embedding);
      if (localMatch) {
        return {
          id: remotePayload.id ?? localMatch.id,
          item: localMatch.item,
          category: localMatch.category,
          confidence: localMatch.confidence,
          timestamp: new Date().toISOString(),
          tips: ensureTips(localMatch.category, remotePayload.tips ?? []),
          source: 'local-cosine'
        };
      }
    }

    if (remotePayload) {
      const category = normalizeCategory(
        remotePayload.category ?? remotePayload.prediction
      );
      return {
        id: remotePayload.id ?? String(Date.now()),
        item: remotePayload.item ?? remotePayload.label ?? '未知物品',
        category,
        confidence: Number(remotePayload.confidence ?? 0.4),
        timestamp: remotePayload.timestamp ?? new Date().toISOString(),
        tips: ensureTips(category, remotePayload.tips ?? []),
        source: 'edge'
      };
    }

    return fallbackResult(
      this.initializationError ??
        'Edge 分类不可用，且未收到可用于本地检索的 embedding。'
    );
  }

  async classifyWithEdge(photo) {
    if (!edgeFunctionUrl || !supabaseAnonKey || !photo) {
      return null;
    }
    const imageBase64 = await toBase64(photo);
    if (!imageBase64) {
      throw new Error('未读取到照片');
    }
    const response = await fetch(edgeFunctionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${supabaseAnonKey}`
      },
      body: JSON.stringify({
        image: imageBase64,
        mimeType: photo?.mime ?? 'image/jpeg',
        includeEmbedding: true,
        returnEmbedding: true,
        mode: 'embedding'
      })
    });
    if (!response.ok) {
      const message = await response.text();
      throw new Error(message || 'Edge Function 调用失败');
    }
    const payload = await response.json();
    const embedding = parseEmbedding(payload);
    return {
      ...payload,
      embedding
    };
  }

  async findBestMatch(imageEmbedding) {
    if (!this.ready || !this.knowledgeBase.length) return null;
    const normalizedImage = alignAndNormalize(imageEmbedding, this.dimension);
    if (!normalizedImage) return null;

    let bestScore = -Infinity;
    let bestMatch = null;

    for (let idx = 0; idx < this.knowledgeBase.length; idx += 1) {
      const row = this.knowledgeBase[idx];
      const score = dot(normalizedImage, row.embedding);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = row;
      }
      if ((idx + 1) % SEARCH_CHUNK_SIZE === 0) {
        await yieldToEventLoop();
      }
    }

    if (!bestMatch || !Number.isFinite(bestScore)) return null;
    return {
      id: bestMatch.id,
      item: bestMatch.label,
      category: bestMatch.category,
      confidence: Math.max(0, bestScore),
      accepted: bestScore >= CONFIDENCE_THRESHOLD
    };
  }
}

export const classifierService = new ClassifierService();
