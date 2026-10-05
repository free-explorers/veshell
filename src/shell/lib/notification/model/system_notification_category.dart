/// `category` hint values the shell sets on its own transient notifications
/// (volume, brightness, battery). They let the notification widget pick the
/// right icon without a real desktop entry, and mark the notification as a
/// system notification rather than a D-Bus one.
const systemVolumeCategory = 'x-veshell.volume';
const systemVolumeMutedCategory = 'x-veshell.volume-muted';
const systemBrightnessCategory = 'x-veshell.brightness';
const systemBatteryCategory = 'x-veshell.battery';

/// The system notification categories, used to test whether a notification
/// should render as a system OSD.
const systemNotificationCategories = <String>{
  systemVolumeCategory,
  systemVolumeMutedCategory,
  systemBrightnessCategory,
  systemBatteryCategory,
};
