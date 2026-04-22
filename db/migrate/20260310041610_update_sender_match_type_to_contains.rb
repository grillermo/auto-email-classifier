class UpdateSenderMatchTypeToContains < ActiveRecord::Migration[8.1]
  def up
    Rule.find_each do |rule|
      modified = false
      
      conditions = Array(rule.definition["conditions"]).map do |condition|
        if condition["field"] == "sender" && condition["operator"] == "exact"
          modified = true
          condition.merge("operator" => "contains")
        else
          condition
        end
      end

      if modified
        rule.definition["conditions"] = conditions
        rule.save!
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
