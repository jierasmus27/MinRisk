# frozen_string_literal: true

User.find_or_initialize_by(operator_id: "admin").tap do |u|
  u.password = "password"
  u.password_confirmation = "password"
  u.save!
end

company = Company.find_or_create_by!(name: "Demo Corp") do |c|
  c.address_line1 = "1 Market Street"
  c.city = "San Francisco"
  c.country_iso = "US"
end

Project.find_or_create_by!(company: company, name: "Demo Project") do |p|
  p.currency_iso = "USD"
  p.time_zone = "UTC"
  p.monte_carlo_iterations = 10_000
  p.confidence_levels = [ 10, 50, 90 ]
end

puts "Seeded operator_id=admin password=password, Demo Corp / Demo Project."
