Helileo::NavigeoIntegration.on_check_success do
  Helileo::NavigeoFetchCreateJob.perform_later
end

Helileo::NavigeoIntegration.run every: :day do
  Helileo::NavigeoFetchCreateJob.perform_now
end

Helileo::NavigeoIntegration.on_logout do
  Sensor
    .where(vendor_euid: :helileo)
    .pluck(:euid)
    .each do |serial_number|
    Helileo::NavigeoIntegration.unset_hooks(serial_number, "ekylibre|example\.org").execute
  end
    .map do |euid|
    Sensor.find_by_euid(euid).destroy
  end
end
