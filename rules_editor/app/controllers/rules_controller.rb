# frozen_string_literal: true

class RulesController < ApplicationController
  before_action :set_rule, only: %i[show edit update]

  def index
    @active_rules = Rule.active.ordered
    @inactive_rules = Rule.where(active: false).ordered
  end

  def show; end

  def edit
    @definition = @rule.definition.with_indifferent_access
  end

  def update
    @rule.assign_attributes(permitted_rule_attributes)
    @rule.definition = Rules::DefinitionBuilder.new(rule_params).build

    if @rule.save
      return apply_now if save_and_apply?

      redirect_to rule_path(@rule), notice: "Rule saved"
    else
      @definition = @rule.definition.with_indifferent_access
      flash.now[:alert] = @rule.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
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

  def appy_all
    result = Rules::ListenerCycle.new(dry_run: ActiveModel::Type::Boolean.new.cast(params[:dry_run])).run!
    render json: result
  rescue StandardError => e
    render json: {
      ok: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  private

  def apply_now
    result = Rules::OneOffApplier.new(rule: @rule).apply!(query: "in:inbox")
    redirect_to rule_path(@rule), notice: "Rule saved and applied (matched: #{result[:matched_count]}, applied: #{result[:applied_count]})"
  rescue StandardError => e
    redirect_to rule_path(@rule), alert: "Rule saved, but immediate apply failed: #{e.message}"
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

  def valid_reorder_payload?(ordered_ids, active_ids)
    ordered_ids.length == active_ids.length && ordered_ids.sort == active_ids.sort
  end
end
