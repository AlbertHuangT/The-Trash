import * as Haptics from 'expo-haptics';
import { useEffect, useState } from 'react';
import { Platform, Pressable, Text, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring
} from 'react-native-reanimated';

import { useTheme } from 'src/theme/ThemeProvider';

const resolveSegmentHaptic = (value) => {
  switch (value) {
    case 'selection':
      return { type: 'selection' };
    case 'soft':
      return { type: 'impact', style: Haptics.ImpactFeedbackStyle.Soft };
    case 'rigid':
      return { type: 'impact', style: Haptics.ImpactFeedbackStyle.Rigid };
    case 'medium':
      return { type: 'impact', style: Haptics.ImpactFeedbackStyle.Medium };
    case 'heavy':
      return { type: 'impact', style: Haptics.ImpactFeedbackStyle.Heavy };
    case 'light':
      return { type: 'impact', style: Haptics.ImpactFeedbackStyle.Light };
    case 'none':
    default:
      return { type: 'none' };
  }
};

export default function TrashSegmentedControl({
  options,
  value,
  onChange,
  style,
  optionStyle,
  labelStyle
}) {
  const theme = useTheme();
  const [layoutWidth, setLayoutWidth] = useState(0);
  const indicatorX = useSharedValue(0);

  const padding =
    theme.components?.segmented?.padding ?? theme.spacing?.xs ?? 8;
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 20,
    letterSpacing: 0.22
  };
  const spring = theme.animationConfig?.segmentedSpring ??
    theme.motion?.springs?.snappy ?? {
      damping: 18,
      stiffness: 280,
      mass: 0.34
    };
  const borderCurveStyle =
    Platform.OS === 'ios' && theme.shape?.borderCurve === 'continuous'
      ? { borderCurve: 'continuous' }
      : null;
  const activeIndex = Math.max(
    0,
    options.findIndex((option) => option.value === value)
  );
  const optionCount = Math.max(options.length, 1);
  const segmentWidth =
    layoutWidth > 0 ? (layoutWidth - padding * 2) / optionCount : 0;

  useEffect(() => {
    if (!segmentWidth) return;
    indicatorX.value = withSpring(padding + segmentWidth * activeIndex, spring);
  }, [activeIndex, indicatorX, padding, segmentWidth, spring]);

  const indicatorStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: indicatorX.value }],
    width: segmentWidth > 0 ? Math.max(0, segmentWidth - 2) : 0
  }));

  const handlePress = async (nextValue) => {
    if (nextValue === value) return;
    try {
      const haptic = resolveSegmentHaptic(theme.haptics?.segmentedImpact);
      if (haptic.type === 'impact') {
        await Haptics.impactAsync(haptic.style);
      } else if (haptic.type === 'selection') {
        await Haptics.selectionAsync();
      }
    } catch {
      // Ignore haptics failure.
    }
    onChange?.(nextValue);
  };

  if (!options?.length) return null;

  return (
    <View
      onLayout={(event) => setLayoutWidth(event.nativeEvent.layout.width)}
      style={[
        {
          position: 'relative',
          flexDirection: 'row',
          width: '100%',
          alignSelf: 'stretch',
          backgroundColor: theme.palette.elevated ?? theme.palette.card,
          borderRadius: theme.radii?.segmented ?? 20,
          ...borderCurveStyle,
          padding,
          marginBottom: theme.spacing?.fieldGap ?? 24
        },
        style
      ]}
    >
      {segmentWidth > 0 ? (
        <Animated.View
          pointerEvents="none"
          style={[
            {
              position: 'absolute',
              top: padding,
              bottom: padding,
              borderRadius: (theme.radii?.segmented ?? 20) - padding,
              ...borderCurveStyle,
              backgroundColor:
                theme.palette.overlay ?? `${theme.accents.blue}2a`,
              shadowColor: theme.accents.blue,
              shadowOpacity: 0.08,
              shadowRadius: 6
            },
            indicatorStyle
          ]}
        />
      ) : null}
      {options.map((option) => {
        const active = option.value === value;
        return (
          <Pressable
            key={option.value}
            onPress={() => handlePress(option.value)}
            style={({ pressed }) => [
              {
                flex: 1,
                borderRadius: (theme.radii?.segmented ?? 20) - padding,
                ...borderCurveStyle,
                minHeight: theme.sizes?.segmentedMinHeight ?? 48,
                paddingVertical: theme.spacing?.sm ?? 12,
                alignItems: 'center',
                justifyContent: 'center',
                opacity: pressed ? 0.84 : 1
              },
              optionStyle
            ]}
          >
            <Text
              style={[
                {
                  color: active
                    ? theme.palette.textPrimary
                    : (theme.palette.textTertiary ??
                      theme.palette.textSecondary),
                  fontWeight: active ? '700' : '600',
                  fontSize: labelType.size ?? 13,
                  lineHeight: labelType.lineHeight ?? 18,
                  letterSpacing: active
                    ? -0.08
                    : (labelType.letterSpacing ?? 0.26),
                  textAlign: 'center'
                },
                labelStyle
              ]}
            >
              {option.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}
