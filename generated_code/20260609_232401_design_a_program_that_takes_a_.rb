#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'securerandom'

# Simple vehicle representation
Vehicle = Struct.new(:id, :speed, :delay, :passengers)

# Generate a random fleet (simulating live feed)
def generate_vehicles(count)
  (0...count).map do
    Vehicle.new(
      SecureRandom.hex(3),
      rand(20..80),          # speed km/h
      rand(-5..10),          # delay minutes (negative = early)
      rand(0..100)           # passenger count
    )
  end
end

# Map vehicle attributes to visual properties
def vehicle_to_petal(vehicle, index, total)
  angle = (360.0 / total) * index
  radius = 100 + vehicle.speed * 2          # base radius + speed influence
  hue = ((vehicle.delay + 5) / 15.0) * 360  # delay -5..10 => hue 0..360
  hue = hue.clamp(0, 360)
  opacity = 0.6 + (vehicle.passengers / 200.0) # more passengers => more opaque
  opacity = opacity.clamp(0.3, 1.0)

  # Stroke dash pattern based on passenger count
  dash = vehicle.passengers % 12 + 4

  {
    angle: angle,
    radius: radius,
    hue: hue,
    opacity: opacity,
    dash: dash
  }
end

# Build SVG string for current fleet
def build_svg(vehicles)
  width = height = 800
  center = width / 2
  total = vehicles.size
  petals = vehicles.each_with_index.map do |v, i|
    p = vehicle_to_petal(v, i, total)
    # petal as rotated ellipse
    <<~PATH
      <ellipse cx="#{center}" cy="#{center - p[:radius]}" rx="30" ry="80"
        transform="rotate(#{p[:angle]}, #{center}, #{center})"
        fill="hsla(#{p[:hue]},70%,50%,#{p[:opacity]})"
        stroke="black" stroke-width="1" stroke-dasharray="#{p[:dash]},#{p[:dash]}" />
    PATH
  end.join("\n")

  <<~SVG
    <?xml version="1.0" encoding="UTF-8"?>
    <svg width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}"
         xmlns="http://www.w3.org/2000/svg" version="1.1">
      <rect width="100%" height="100%" fill="white"/>
      #{petals}
    </svg>
  SVG
end

# Generate a short rhyming couplet describing the mood
def generate_couplet(vehicles)
  avg_delay = vehicles.sum(&:delay).to_f / vehicles.size
  mood = if avg_delay > 5
           "traffic's a tide, all stuck inside"
         elsif avg_delay < -2
           "buses glide, on time they ride"
         else
           "the city hums, no frantic drums"
         end
  "The schedule shifts anew, #{mood}."
end

# Main loop – updates every few seconds
def run
  fleet_size = 12
  loop do
    vehicles = generate_vehicles(fleet_size)
    svg = build_svg(vehicles)
    File.write('mandala.svg', svg)
    puts generate_couplet(vehicles)
    sleep 4
  end
end

run if __FILE__ == $PROGRAM_NAME