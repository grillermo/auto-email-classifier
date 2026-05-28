rules = Rule.active.ordered
lines = []
lines << "# Active rules exported #{Date.today} — run AFTER first Google sign-in"
lines << "user = User.first || raise(\"No user found. Sign in with Google first, then run bin/rails db:seed\")"
lines << ""
rules.each do |r|
  lines << "Rule.find_or_create_by!("
  lines << "  user: user,"
  lines << "  definition: #{r.definition.to_json}"
  lines << ") do |rule|"
  lines << "  rule.name = #{r.name.inspect}"
  lines << "  rule.priority = #{r.priority}"
  lines << "  rule.active = #{r.active}"
  lines << "end"
  lines << ""
end
File.write("db/seeds.rb", lines.join("\n"))
puts "Exported #{rules.count} rules to db/seeds.rb"
