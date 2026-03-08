import { useForm } from "@inertiajs/react";

export const CONDITION_FIELDS = ["sender", "subject", "body"];
export const CONDITION_OPERATORS = ["exact", "contains"];
export const ACTION_TYPES = ["add_label", "remove_label", "mark_read", "trash"];

const DEFAULT_CONDITION = {
  field: "sender",
  operator: "contains",
  value: "",
  caseSensitive: false,
};

const DEFAULT_ACTION = {
  type: "mark_read",
  label: "",
};

export function actionRequiresLabel(type) {
  return type === "add_label" || type === "remove_label";
}

function asBoolean(value) {
  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "string") {
    return value === "true";
  }

  return Boolean(value);
}

function normalizeCondition(condition) {
  const field = CONDITION_FIELDS.includes(condition?.field) ? condition.field : DEFAULT_CONDITION.field;
  const operator = CONDITION_OPERATORS.includes(condition?.operator)
    ? condition.operator
    : DEFAULT_CONDITION.operator;

  return {
    field,
    operator,
    value: condition?.value?.toString() || "",
    caseSensitive: asBoolean(condition?.caseSensitive ?? condition?.case_sensitive),
  };
}

function normalizeAction(action) {
  const type = ACTION_TYPES.includes(action?.type) ? action.type : DEFAULT_ACTION.type;
  return {
    type,
    label: action?.label?.toString() || "",
  };
}

function initialConditions(definition) {
  const conditions = Array.isArray(definition?.conditions) ? definition.conditions : [];
  const normalized = conditions.map(normalizeCondition);
  return normalized.length > 0 ? normalized : [{ ...DEFAULT_CONDITION }];
}

function initialActions(definition) {
  const actions = Array.isArray(definition?.actions) ? definition.actions : [];
  const normalized = actions.map(normalizeAction);
  return normalized.length > 0 ? normalized : [{ ...DEFAULT_ACTION }];
}

function mapConditionsForParams(conditions) {
  return conditions.map((condition) => ({
    field: condition.field,
    operator: condition.operator,
    value: condition.value,
    case_sensitive: condition.caseSensitive,
  }));
}

function mapActionsForParams(actions) {
  return actions.map((action) => ({
    type: action.type,
    label: actionRequiresLabel(action.type) ? action.label : "",
  }));
}

export function useRulesForm({ rule, definition, updateUrl }) {
  const form = useForm({
    name: rule.name || "",
    priority: rule.priority?.toString() || "1",
    active: asBoolean(rule.active),
    matchMode: definition?.matchMode === "any" ? "any" : "all",
    conditions: initialConditions(definition),
    actions: initialActions(definition),
  });

  const setName = (name) => {
    form.setData("name", name);
  };

  const setPriority = (priority) => {
    form.setData("priority", priority);
  };

  const setActive = (active) => {
    form.setData("active", active);
  };

  const setMatchMode = (matchMode) => {
    form.setData("matchMode", matchMode === "any" ? "any" : "all");
  };

  const addCondition = () => {
    form.setData((data) => ({
      ...data,
      conditions: [...data.conditions, { ...DEFAULT_CONDITION }],
    }));
  };

  const removeCondition = (index) => {
    form.setData((data) => {
      if (data.conditions.length <= 1) {
        return data;
      }

      return {
        ...data,
        conditions: data.conditions.filter((_, currentIndex) => currentIndex !== index),
      };
    });
  };

  const updateCondition = (index, key, value) => {
    form.setData((data) => ({
      ...data,
      conditions: data.conditions.map((condition, currentIndex) =>
        currentIndex === index ? { ...condition, [key]: value } : condition
      ),
    }));
  };

  const addAction = () => {
    form.setData((data) => ({
      ...data,
      actions: [...data.actions, { ...DEFAULT_ACTION }],
    }));
  };

  const removeAction = (index) => {
    form.setData((data) => {
      if (data.actions.length <= 1) {
        return data;
      }

      return {
        ...data,
        actions: data.actions.filter((_, currentIndex) => currentIndex !== index),
      };
    });
  };

  const updateAction = (index, key, value) => {
    form.setData((data) => ({
      ...data,
      actions: data.actions.map((action, currentIndex) => {
        if (currentIndex !== index) {
          return action;
        }

        if (key === "type") {
          return {
            ...action,
            type: value,
            label: actionRequiresLabel(value) ? action.label : "",
          };
        }

        return { ...action, [key]: value };
      }),
    }));
  };

  const submit = (commitAction = "save") => {
    form.transform((data) => ({
      rule: {
        name: data.name,
        priority: data.priority,
        active: data.active,
        match_mode: data.matchMode,
        conditions_attributes: mapConditionsForParams(data.conditions),
        actions_attributes: mapActionsForParams(data.actions),
      },
      commit_action: commitAction,
    }));

    form.patch(updateUrl, { preserveScroll: true });
  };

  return {
    ...form,
    setName,
    setPriority,
    setActive,
    setMatchMode,
    addCondition,
    removeCondition,
    updateCondition,
    addAction,
    removeAction,
    updateAction,
    submit,
  };
}
