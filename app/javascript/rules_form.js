import { useForm } from "@inertiajs/react";

export const CONDITION_FIELDS = [
  { value: "sender", label: "Sender" },
  { value: "subject", label: "Subject" },
  { value: "body", label: "Body" },
];
export const CONDITION_OPERATORS = [
  { value: "contains", label: "Contains" },
];
export const ACTION_TYPES = [
  { value: "add_label", label: "Add label" },
  { value: "remove_label", label: "Remove label" },
  { value: "mark_read", label: "Mark read" },
  { value: "trash", label: "Trash" },
  { value: "run_script", label: "Run script" },
];

const DEFAULT_CONDITION = {
  field: "sender",
  operator: "contains",
  value: "",
  caseSensitive: false,
};

const DEFAULT_ACTION = {
  type: "mark_read",
  label: "",
  script: "",
};

export function actionRequiresLabel(type) {
  return type === "add_label" || type === "remove_label";
}

export function actionRequiresScript(type) {
  return type === "run_script";
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
  const field = CONDITION_FIELDS.some((f) => f.value === condition?.field) ? condition.field : DEFAULT_CONDITION.field;
  const operator = CONDITION_OPERATORS.some((o) => o.value === condition?.operator)
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
  const type = ACTION_TYPES.some((a) => a.value === action?.type) ? action.type : DEFAULT_ACTION.type;
  return {
    type,
    label: action?.label?.toString() || "",
    script: action?.script?.toString() || "",
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
    script: actionRequiresScript(action.type) ? action.script : "",
  }));
}

export function useDeleteRuleForm({ deleteUrl }) {
  const form = useForm({});

  const destroy = () => {
    form.delete(deleteUrl);
  };

  return { ...form, destroy };
}

export function useRulesForm({ rule, definition, updateUrl, submitMethod = "patch" }) {
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
            script: actionRequiresScript(value) ? action.script : "",
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

    if (submitMethod === "post") {
      form.post(updateUrl, { preserveScroll: true });
    } else {
      form.patch(updateUrl, { preserveScroll: true });
    }
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
