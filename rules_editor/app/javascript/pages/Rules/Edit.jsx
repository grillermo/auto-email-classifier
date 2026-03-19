import { Head } from "@inertiajs/react";
import {
  ACTION_TYPES,
  CONDITION_FIELDS,
  CONDITION_OPERATORS,
  actionRequiresLabel,
  useRulesForm,
} from "../../rules_form";

function flattenErrorMessages(formErrors) {
  return Object.values(formErrors).flatMap((errorValue) => {
    if (errorValue == null) return [];
    if (Array.isArray(errorValue)) return errorValue.map((entry) => entry.toString());
    return [errorValue.toString()];
  });
}

function Toggle({ checked, onChange }) {
  return (
    <label className="flex items-center gap-2 cursor-pointer">
      <div className="relative inline-flex items-center">
        <input type="checkbox" className="sr-only peer" checked={checked} onChange={onChange} />
        <div className="w-9 h-5 bg-outline-variant peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-secondary"></div>
      </div>
      <span className="text-xs font-medium text-on-surface-variant">Case-sensitive</span>
    </label>
  );
}

export default function RulesEdit({ rule, definition, updateUrl, backUrl, errorMessages = [] }) {
  const form = useRulesForm({ rule, definition, updateUrl });
  const combinedErrorMessages = [...errorMessages, ...flattenErrorMessages(form.errors)];
  const uniqueErrorMessages = Array.from(new Set(combinedErrorMessages.filter(Boolean)));

  const onSubmit = (event) => {
    event.preventDefault();
    const action = event.nativeEvent.submitter?.value || "save";
    form.submit(action);
  };

  return (
    <>
      <Head title={`Edit ${rule.name}`} />

      {/* Page header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight text-on-surface">Rule Editor</h1>
          <p className="text-on-surface-variant mt-1">
            Configure automated logic for your incoming messages.
          </p>
        </div>
      </div>

      {uniqueErrorMessages.length > 0 ? (
        <div className="mb-6 px-6 py-4 rounded-xl bg-error-container text-on-surface flex items-start gap-3">
          <span className="material-symbols-outlined text-error mt-0.5">error</span>
          <span className="text-sm">{uniqueErrorMessages.join(". ")}</span>
        </div>
      ) : null}

      <form onSubmit={(e) => e.preventDefault()} className="space-y-8 pb-28">

        {/* Basics */}
        <section className="bg-surface-container-lowest p-8 rounded-2xl shadow-sm">
          <div className="flex items-center gap-3 mb-6">
            <span className="material-symbols-outlined text-primary">info</span>
            <h2 className="text-xl font-bold text-on-surface">Basics</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
            <div className="md:col-span-8">
              <label className="block text-sm font-semibold text-on-surface-variant mb-2">
                Rule Name
              </label>
              <input
                type="text"
                required
                value={form.data.name}
                onChange={(event) => form.setName(event.target.value)}
                placeholder="e.g., Forward Invoices to Finance"
                className="w-full bg-surface-container-low border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-4 py-3 rounded-t-lg transition-colors text-on-surface"
              />
            </div>
            <div className="md:col-span-2">
              <label className="block text-sm font-semibold text-on-surface-variant mb-2">
                Priority
              </label>
              <input
                type="number"
                min="1"
                required
                value={form.data.priority}
                onChange={(event) => form.setPriority(event.target.value)}
                className="w-full bg-surface-container-low border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-4 py-3 rounded-t-lg transition-colors text-on-surface"
              />
            </div>
            <div className="md:col-span-2 flex items-end pb-3">
              <label className="flex items-center gap-3 cursor-pointer group">
                <input
                  type="checkbox"
                  checked={form.data.active}
                  onChange={(event) => form.setActive(event.target.checked)}
                  className="w-5 h-5 rounded border-outline-variant text-primary focus:ring-primary"
                />
                <span className="text-sm font-semibold text-on-surface-variant group-hover:text-on-surface">
                  Active
                </span>
              </label>
            </div>
          </div>
        </section>

        {/* Conditions Builder */}
        <section className="bg-surface-container-lowest p-8 rounded-2xl shadow-sm">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-primary">filter_list</span>
              <h2 className="text-xl font-bold text-on-surface">Conditions Builder</h2>
            </div>
            <div className="inline-flex bg-surface-container-low p-1 rounded-xl">
              <button
                type="button"
                onClick={() => form.setMatchMode("all")}
                className={`px-4 py-1.5 text-sm font-semibold rounded-lg transition-colors ${
                  form.data.matchMode === "all"
                    ? "bg-white shadow-sm text-on-surface"
                    : "text-on-surface-variant hover:text-on-surface"
                }`}
              >
                Match all conditions
              </button>
              <button
                type="button"
                onClick={() => form.setMatchMode("any")}
                className={`px-4 py-1.5 text-sm font-semibold rounded-lg transition-colors ${
                  form.data.matchMode === "any"
                    ? "bg-white shadow-sm text-on-surface"
                    : "text-on-surface-variant hover:text-on-surface"
                }`}
              >
                Match any condition
              </button>
            </div>
          </div>

          <div className="space-y-4">
            {form.data.conditions.map((condition, index) => (
              <div
                key={`condition-${index}`}
                className="flex flex-col md:flex-row items-start md:items-center gap-4 bg-surface-container-low/50 p-4 rounded-xl group"
              >
                <div className="w-full md:w-1/4">
                  <select
                    value={condition.field}
                    onChange={(event) => form.updateCondition(index, "field", event.target.value)}
                    className="w-full bg-white border-0 text-sm py-2.5 px-3 rounded-lg focus:ring-2 focus:ring-primary/20 text-on-surface"
                  >
                    {CONDITION_FIELDS.map((field) => (
                      <option key={field} value={field}>
                        {field}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="w-full md:w-1/4">
                  <select
                    value={condition.operator}
                    onChange={(event) =>
                      form.updateCondition(index, "operator", event.target.value)
                    }
                    className="w-full bg-white border-0 text-sm py-2.5 px-3 rounded-lg focus:ring-2 focus:ring-primary/20 text-on-surface"
                  >
                    {CONDITION_OPERATORS.map((operator) => (
                      <option key={operator} value={operator}>
                        {operator}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="w-full md:flex-1">
                  <input
                    type="text"
                    value={condition.value}
                    required
                    onChange={(event) => form.updateCondition(index, "value", event.target.value)}
                    placeholder="Value..."
                    className="w-full bg-white border-0 text-sm py-2.5 px-3 rounded-lg focus:ring-2 focus:ring-primary/20 text-on-surface"
                  />
                </div>
                <div className="flex items-center gap-4">
                  <Toggle
                    checked={condition.caseSensitive}
                    onChange={(event) =>
                      form.updateCondition(index, "caseSensitive", event.target.checked)
                    }
                  />
                  <button
                    type="button"
                    onClick={() => form.removeCondition(index)}
                    disabled={form.data.conditions.length <= 1}
                    className="p-1.5 text-error opacity-0 group-hover:opacity-100 transition-opacity disabled:opacity-0 disabled:cursor-not-allowed"
                    aria-label="Remove condition"
                  >
                    <span className="material-symbols-outlined text-lg">delete</span>
                  </button>
                </div>
              </div>
            ))}

            <button
              type="button"
              onClick={form.addCondition}
              className="flex items-center gap-2 text-sm font-bold text-primary hover:bg-primary-container/20 px-4 py-2 rounded-lg transition-colors mt-2"
            >
              <span className="material-symbols-outlined text-lg">add_circle</span>
              Add Condition
            </button>
          </div>
        </section>

        {/* Actions Builder */}
        <section className="bg-surface-container-lowest p-8 rounded-2xl shadow-sm">
          <div className="flex items-center gap-3 mb-8">
            <span className="material-symbols-outlined text-primary">bolt</span>
            <h2 className="text-xl font-bold text-on-surface">Actions Builder</h2>
          </div>

          <div className="space-y-4">
            {form.data.actions.map((action, index) => {
              const requiresLabel = actionRequiresLabel(action.type);
              return (
                <div
                  key={`action-${index}`}
                  className="flex flex-col md:flex-row items-start md:items-center gap-4 bg-surface-container-low/50 p-4 rounded-xl group"
                >
                  <div className="w-full md:w-1/3">
                    <select
                      value={action.type}
                      onChange={(event) => form.updateAction(index, "type", event.target.value)}
                      className="w-full bg-white border-0 text-sm py-2.5 px-3 rounded-lg focus:ring-2 focus:ring-primary/20 text-on-surface"
                    >
                      {ACTION_TYPES.map((type) => (
                        <option key={type} value={type}>
                          {type}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="w-full md:flex-1">
                    <input
                      type="text"
                      value={action.label}
                      onChange={(event) => form.updateAction(index, "label", event.target.value)}
                      required={requiresLabel}
                      disabled={!requiresLabel}
                      placeholder="Label name..."
                      className={`w-full bg-white border-0 text-sm py-2.5 px-3 rounded-lg focus:ring-2 focus:ring-primary/20 text-on-surface ${
                        !requiresLabel ? "opacity-40 cursor-not-allowed" : ""
                      }`}
                    />
                  </div>
                  <button
                    type="button"
                    onClick={() => form.removeAction(index)}
                    disabled={form.data.actions.length <= 1}
                    className="p-1.5 text-error opacity-0 group-hover:opacity-100 transition-opacity disabled:opacity-0 disabled:cursor-not-allowed"
                    aria-label="Remove action"
                  >
                    <span className="material-symbols-outlined text-lg">delete</span>
                  </button>
                </div>
              );
            })}

            <button
              type="button"
              onClick={form.addAction}
              className="flex items-center gap-2 text-sm font-bold text-primary hover:bg-primary-container/20 px-4 py-2 rounded-lg transition-colors mt-2"
            >
              <span className="material-symbols-outlined text-lg">add_circle</span>
              Add Action
            </button>
          </div>
        </section>
      </form>

      {/* Sticky footer */}
      <div className="fixed bottom-0 left-0 right-0 bg-white/80 backdrop-blur-xl border-t border-surface-container-high py-4 px-6 z-50">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <a
            href={backUrl}
            className="flex items-center gap-2 text-on-surface-variant hover:text-on-surface font-semibold px-4 py-2.5 rounded-xl hover:bg-surface-container transition-colors"
          >
            <span className="material-symbols-outlined text-xl">close</span>
            Discard Changes
          </a>
          <div className="flex items-center gap-3">
            <button
              type="submit"
              form="rule-editor-form"
              value="save"
              disabled={form.processing}
              onClick={() => form.submit("save")}
              className="bg-surface-container-highest text-on-surface font-bold px-6 py-2.5 rounded-xl hover:bg-surface-container-high transition-colors disabled:opacity-70 disabled:cursor-not-allowed"
            >
              Save
            </button>
            <button
              type="submit"
              value="save_and_apply"
              disabled={form.processing}
              onClick={() => form.submit("save_and_apply")}
              className="bg-primary text-on-primary font-bold px-8 py-2.5 rounded-xl shadow-lg hover:opacity-90 active:scale-95 transition-all disabled:opacity-70 disabled:cursor-not-allowed"
            >
              Save and Apply Now
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
