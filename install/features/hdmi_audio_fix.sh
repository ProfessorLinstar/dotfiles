# Feature: pin the Framework 16's Radeon 780M at the high performance level, which fixes choppy HDMI audio.

HDMI_AUDIO_FIX_SRC="root/etc/systemd/system"
HDMI_AUDIO_FIX_UNIT="hdmi-audio-fix.service"
# PCI vendor:device ID of the 780M, matched instead of its address or card number, which can change.
HDMI_AUDIO_FIX_ID="0x1002:0x15bf"

# Print the sysfs directory of each PCI device with ID $1 (vendor:device).
pci_devices_with_id() {
  local dev
  for dev in /sys/bus/pci/devices/*; do
    [[ "$(cat "$dev/vendor" 2>/dev/null):$(cat "$dev/device" 2>/dev/null)" == "$1" ]] && echo "$dev"
  done
  return 0
}

# Install hdmi-audio-fix.service into /etc (needs sudo), which sets the 780M to the high performance level at boot
# and after each resume.
#
# @machine framework16
# @os linux
# @gui any
feature_hdmi_audio_fix() {
  keep_across_steamos_updates hdmi_audio_fix \
    $(unit_keep_paths "$SYSTEM_UNITS_DIR" "$DOTFILES_ROOT/$HDMI_AUDIO_FIX_SRC" "$HDMI_AUDIO_FIX_UNIT")
  f_write_args install_system_units _changed -- "$DOTFILES_ROOT/$HDMI_AUDIO_FIX_SRC" "$HDMI_AUDIO_FIX_UNIT"
  [[ -n "$_changed" ]] || return 0
  info "Check with: cat /sys/bus/pci/devices/*/power_dpm_force_performance_level (the 780M should show high)"
}

# Remove hdmi-audio-fix.service, then set the 780M back to the auto performance level.
uninstall_feature_hdmi_audio_fix() {
  f_write_args uninstall_system_units _removed -- "$HDMI_AUDIO_FIX_UNIT"
  forget_across_steamos_updates hdmi_audio_fix
  [[ -n "$_removed" ]] || return 0
  local dev
  for dev in $(pci_devices_with_id "$HDMI_AUDIO_FIX_ID"); do
    run sudo sh -c "echo auto > $dev/power_dpm_force_performance_level"
  done
}
