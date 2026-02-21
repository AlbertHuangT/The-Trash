import * as Haptics from 'expo-haptics';
import { ActivityIndicator, Platform, Pressable, Text } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming
} from 'react-native-reanimated';

import { useTheme } from 'src/theme/ThemeProvider';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

const resolveImpactStyle = (value) => {
  switch (value) {
    case 'soft':
      return Haptics.ImpactFeedbackStyle.Soft;
    case 'rigid':
      return Haptics.ImpactFeedbackStyle.Rigid;
    case 'medium':
      return Haptics.ImpactFeedbackStyle.Medium;
    case 'heavy':
      return Haptics.ImpactFeedbackStyle.Heavy;
    case 'light':
    default:
      return Haptics.ImpactFeedbackStyle.Light;
  }
};

const parseHapticPreference = (value) => {
  if (!value || value === 'none') {
    return { type: 'none' };
  }
  if (value === 'selection') {
    return { type: 'selection' };
  }
  return {
    type: 'impact',
    style: resolveImpactStyle(value)
  };
};

const resolveButtonHaptic = (theme, variant) => {
  const haptics = theme.haptics ?? {};

  if (variant === 'ghost') {
    return parseHapticPreference(haptics.buttonGhostImpact ?? 'none');
  }
  if (variant === 'outline') {
    return parseHapticPreference(haptics.buttonOutlineImpact ?? 'none');
  }
  if (variant === 'secondary') {
    return parseHapticPreference(haptics.buttonSecondaryImpact ?? 'none');
  }
  return parseHapticPreference(
    haptics.buttonPrimaryImpact ?? haptics.buttonImpact ?? 'light'
  );
};

const variants = {
  primary: (theme) => ({
    backgroundColor: theme.accents.blue,
    textColor: '#050a15',
    borderColor: theme.accents.blue
  }),
  secondary: (theme) => ({
    backgroundColor: theme.accents.green,
    textColor: '#041208',
    borderColor: theme.accents.green
  }),
  outline: (theme) => ({
    backgroundColor: theme.palette.elevated ?? 'transparent',
    textColor: theme.palette.textPrimary,
    borderColor: theme.palette.divider ?? 'rgba(255,255,255,0.2)'
  }),
  ghost: (theme) => ({
    backgroundColor: 'transparent',
    textColor: theme.palette.textSecondary,
    borderColor: 'transparent'
  })
};

export default function TrashButton({
  title,
  onPress,
  variant = 'primary',
  loading = false,
  disabled = false,
  style,
  textStyle
}) {
  const theme = useTheme();
  const palette = variants[variant]?.(theme) ?? variants.primary(theme);
  const isDisabled = disabled || loading;

  const scale = useSharedValue(1);
  const pressedOpacity = useSharedValue(1);

  const pressInDuration = theme.motion?.durations?.tapIn ?? 110;
  const pressOutDuration = theme.motion?.durations?.tapOut ?? 180;
  const curve = theme.motion?.curves?.emphasize ?? [0.22, 1, 0.36, 1];
  const pressInSpring = theme.animationConfig?.pressInSpring ??
    theme.motion?.springs?.pressIn ?? {
      damping: 18,
      stiffness: 360,
      mass: 0.26
    };
  const pressOutSpring = theme.animationConfig?.pressOutSpring ??
    theme.motion?.springs?.pressOut ?? {
      damping: 20,
      stiffness: 320,
      mass: 0.24
    };
  const buttonPadding = theme.components?.button ?? {};
  const labelType = theme.typography?.body ?? {
    size: 16,
    lineHeight: 25,
    letterSpacing: 0.14
  };
  const borderCurveStyle =
    Platform.OS === 'ios' && theme.shape?.borderCurve === 'continuous'
      ? { borderCurve: 'continuous' }
      : null;

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: pressedOpacity.value
  }));

  const handlePressIn = () => {
    scale.value = withSpring(0.972, pressInSpring);
    pressedOpacity.value = withTiming(0.92, {
      duration: pressInDuration,
      easing: Easing.bezier(...curve)
    });
  };

  const handlePressOut = () => {
    scale.value = withSpring(1, pressOutSpring);
    pressedOpacity.value = withTiming(1, {
      duration: pressOutDuration,
      easing: Easing.bezier(...curve)
    });
  };

  const handlePress = async () => {
    if (isDisabled) return;
    try {
      const haptic = resolveButtonHaptic(theme, variant);
      if (haptic.type === 'impact') {
        await Haptics.impactAsync(haptic.style);
      } else if (haptic.type === 'selection') {
        await Haptics.selectionAsync();
      }
    } catch {
      // Ignore haptics failure on unsupported devices.
    }
    onPress?.();
  };

  return (
    <AnimatedPressable
      accessibilityRole="button"
      disabled={isDisabled}
      onPress={handlePress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      style={[
        animatedStyle,
        {
          opacity: isDisabled ? 0.55 : 1,
          backgroundColor: palette.backgroundColor,
          borderColor: palette.borderColor,
          borderWidth: palette.borderColor === 'transparent' ? 0 : 1,
          borderRadius: theme.radii?.button ?? 20,
          ...borderCurveStyle,
          minHeight: theme.sizes?.buttonHeight ?? 50,
          paddingHorizontal:
            buttonPadding.horizontalPadding ?? theme.spacing?.md ?? 16,
          paddingVertical:
            buttonPadding.verticalPadding ?? theme.spacing?.sm ?? 12,
          alignItems: 'center',
          justifyContent: 'center'
        },
        style
      ]}
    >
      {loading ? (
        <ActivityIndicator color={palette.textColor} />
      ) : (
        <Text
          style={[
            {
              color: palette.textColor,
              fontSize: labelType.size ?? 13,
              lineHeight: labelType.lineHeight ?? 18,
              fontWeight: '600',
              letterSpacing: labelType.letterSpacing ?? 0.26,
              textAlign: 'center'
            },
            textStyle
          ]}
        >
          {title}
        </Text>
      )}
    </AnimatedPressable>
  );
}
