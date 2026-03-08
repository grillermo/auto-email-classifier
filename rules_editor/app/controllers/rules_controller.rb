# frozen_string_literal: true

class RulesController < ApplicationController
  before_action :set_rule, only: %i[show edit update]

  def index
    active_rules = Rule.active.ordered.preload(:rule_applications)
    inactive_rules = Rule.where(active: false).ordered.preload(:rule_applications)

    render inertia: "Rules/Index", props: {
      activeRules: serialize_rules(active_rules),
      inactiveRules: serialize_rules(inactive_rules),
      reorderUrl: reorder_rules_path
    }
  end

  def show
    matching_emails = Rules::MatchingEmailsLoader.new(rule: @rule).load
    @matching_emails = matching_emails.fetch(:emails)
    @matching_emails_total_count = matching_emails.fetch(:total_count)
    @matching_emails_truncated = matching_emails.fetch(:truncated)
    @matching_emails_error = matching_emails.fetch(:error)
  end

  def edit
    render inertia: "Rules/Edit", props: edit_props(@rule)
  end

  def update
    @rule.assign_attributes(permitted_rule_attributes)
    @rule.definition = Rules::DefinitionBuilder.new(rule_params).build

    if @rule.save
      return apply_now if save_and_apply?

      redirect_to_rule_with_flash(notice: "Rule saved")
    else
      render inertia: "Rules/Edit", props: edit_props(@rule, error_messages: @rule.errors.full_messages), status: :unprocessable_entity
    end
  end

  def reorder
    ordered_ids = Array(params[:ordered_ids]).map(&:to_s)

    Rule.transaction do
      active_rules = Rule.active.lock.order(priority: :asc, updated_at: :desc).to_a
      active_ids = active_rules.map { |rule| rule.id.to_s }

      unless valid_reorder_payload?(ordered_ids, active_ids)
        return render json: { ok: false, error: "ordered_ids must match all active rules" }, status: :unprocessable_entity
      end

      ordered_ids.each_with_index do |id, index|
        Rule.where(id: id).update_all(priority: index + 1, updated_at: Time.current)
      end
    end

    render json: { ok: true }
  end

  private

  def apply_now
    result = Rules::OneOffApplier.new(rule: @rule).apply!(query: "in:inbox")
    redirect_to_rule_with_flash(
      notice: "Rule saved and applied (matched: #{result[:matched_count]}, applied: #{result[:applied_count]})"
    )
  rescue StandardError => e
    redirect_to_rule_with_flash(alert: "Rule saved, but immediate apply failed: #{e.message}")
  end

  def permitted_rule_attributes
    rule_params.slice(:name, :active, :priority).to_h
  end

  def rule_params
    params.require(:rule).permit(
      :name,
      :active,
      :priority,
      :match_mode,
      conditions_attributes: %i[field operator value case_sensitive],
      actions_attributes: %i[type label]
    )
  end

  def set_rule
    @rule = Rule.find(params[:id])
  end

  def save_and_apply?
    params[:commit_action] == "save_and_apply"
  end

  def redirect_to_rule_with_flash(notice: nil, alert: nil)
    flash[:notice] = notice if notice
    flash[:alert] = alert if alert

    return inertia_location(rule_path(@rule)) if request.inertia?

    redirect_to rule_path(@rule)
  end

  def valid_reorder_payload?(ordered_ids, active_ids)
    ordered_ids.length == active_ids.length && ordered_ids.sort == active_ids.sort
  end

  def serialize_rules(rules)
    rules.map do |rule|
      {
        id: rule.id.to_s,
        name: rule.name,
        priority: rule.priority,
        conditionsCount: rule.conditions.size,
        actionsCount: rule.actions.size,
        showUrl: rule_path(rule),
        editUrl: edit_rule_path(rule),
        applicationsCount: rule.rule_applications.size
      }
    end
  end

  def edit_props(rule, error_messages: [])
    definition = rule.definition.with_indifferent_access

    {
      rule: {
        id: rule.id.to_s,
        name: rule.name,
        active: rule.active,
        priority: rule.priority
      },
      definition: {
        matchMode: %w[all any].include?(definition[:match_mode].to_s) ? definition[:match_mode].to_s : "all",
        conditions: serialize_conditions_for_edit(definition[:conditions]),
        actions: serialize_actions_for_edit(definition[:actions])
      },
      updateUrl: rule_path(rule),
      backUrl: rule_path(rule),
      errorMessages: Array(error_messages)
    }
  end

  def serialize_conditions_for_edit(conditions)
    serialized_conditions = Array(conditions).filter_map do |condition|
      condition = condition.respond_to?(:to_h) ? condition.to_h.with_indifferent_access : {}

      {
        field: normalize_condition_field(condition[:field]),
        operator: normalize_condition_operator(condition[:operator]),
        value: condition[:value].to_s,
        caseSensitive: ActiveModel::Type::Boolean.new.cast(condition[:case_sensitive])
      }
    end

    return serialized_conditions if serialized_conditions.any?

    [{
      field: "sender",
      operator: "contains",
      value: "",
      caseSensitive: false
    }]
  end

  def serialize_actions_for_edit(actions)
    serialized_actions = Array(actions).filter_map do |action|
      action = action.respond_to?(:to_h) ? action.to_h.with_indifferent_access : {}
      type = normalize_action_type(action[:type])

      {
        type: type,
        label: action[:label].to_s
      }
    end

    return serialized_actions if serialized_actions.any?

    [{
      type: "mark_read",
      label: ""
    }]
  end

  def normalize_condition_field(value)
    value = value.to_s
    %w[sender subject body].include?(value) ? value : "sender"
  end

  def normalize_condition_operator(value)
    value = value.to_s
    %w[exact contains].include?(value) ? value : "contains"
  end

  def normalize_action_type(value)
    value = value.to_s
    %w[add_label remove_label mark_read trash].include?(value) ? value : "mark_read"
  end
end
