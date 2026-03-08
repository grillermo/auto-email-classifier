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
    if (errorValue == null) {
      return [];
    }

    if (Array.isArray(errorValue)) {
      return errorValue.map((entry) => entry.toString());
    }

    return [errorValue.toString()];
  });
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

      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Edit Rule</h1>
          <p className="text-sm text-slate-600">{rule.name}</p>
        </div>
        <a
          href={backUrl}
          className="rounded border border-slate-300 px-3 py-2 text-sm text-slate-700 hover:bg-slate-50"
        >
          Back
        </a>
      </div>

      {uniqueErrorMessages.length > 0 ? (
        <div className="mb-4 rounded border border-rose-300 bg-rose-50 px-4 py-3 text-sm text-rose-800">
          {uniqueErrorMessages.join(". ")}
        </div>
      ) : null}

      <form onSubmit={onSubmit} className="space-y-6">
        <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <h2 className="mb-4 text-lg font-semibold">Basics</h2>

          <div className="grid gap-4 md:grid-cols-3">
            <div className="md:col-span-2">
              <label className="mb-1 block text-sm font-medium text-slate-700" htmlFor="rule-name">
                Name
              </label>
              <input
                id="rule-name"
                type="text"
                required
                value={form.data.name}
                onChange={(event) => form.setName(event.target.value)}
                className="w-full rounded border border-slate-300 px-3 py-2"
              />
            </div>

            <div>
              <label
                className="mb-1 block text-sm font-medium text-slate-700"
                htmlFor="rule-priority"
              >
                Priority
              </label>
              <input
                id="rule-priority"
                type="number"
                min="1"
                required
                value={form.data.priority}
                onChange={(event) => form.setPriority(event.target.value)}
                className="w-full rounded border border-slate-300 px-3 py-2"
              />
            </div>
          </div>

          <div className="mt-4 grid gap-4 md:grid-cols-2">
            <div>
              <label
                className="mb-1 block text-sm font-medium text-slate-700"
                htmlFor="rule-match-mode"
              >
                Match mode
              </label>
              <select
                id="rule-match-mode"
                value={form.data.matchMode}
                onChange={(event) => form.setMatchMode(event.target.value)}
                className="w-full rounded border border-slate-300 px-3 py-2"
              >
                <option value="all">all conditions</option>
                <option value="any">any condition</option>
              </select>
            </div>

            <div className="flex items-end">
              <label className="inline-flex items-center gap-2 text-sm" htmlFor="rule-active">
                <input
                  id="rule-active"
                  type="checkbox"
                  checked={form.data.active}
                  onChange={(event) => form.setActive(event.target.checked)}
                />
                <span>Active</span>
              </label>
            </div>
          </div>
        </section>

        <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold">Conditions</h2>
            <button
              type="button"
              onClick={form.addCondition}
              className="rounded bg-slate-200 px-3 py-2 text-sm font-medium text-slate-800 hover:bg-slate-300"
            >
              Add condition
            </button>
          </div>

          <div className="space-y-3">
            {form.data.conditions.map((condition, index) => (
              <div
                key={`condition-${index}`}
                className="grid gap-2 rounded border border-slate-200 bg-slate-50 p-3 md:grid-cols-[1fr_1fr_2fr_auto_auto]"
              >
                <select
                  value={condition.field}
                  onChange={(event) => form.updateCondition(index, "field", event.target.value)}
                  className="rounded border border-slate-300 px-2 py-1"
                >
                  {CONDITION_FIELDS.map((field) => (
                    <option key={field} value={field}>
                      {field}
                    </option>
                  ))}
                </select>

                <select
                  value={condition.operator}
                  onChange={(event) => form.updateCondition(index, "operator", event.target.value)}
                  className="rounded border border-slate-300 px-2 py-1"
                >
                  {CONDITION_OPERATORS.map((operator) => (
                    <option key={operator} value={operator}>
                      {operator}
                    </option>
                  ))}
                </select>

                <input
                  type="text"
                  value={condition.value}
                  required
                  onChange={(event) => form.updateCondition(index, "value", event.target.value)}
                  className="rounded border border-slate-300 px-2 py-1"
                />

                <label className="inline-flex items-center gap-1 text-xs text-slate-700">
                  <input
                    type="checkbox"
                    checked={condition.caseSensitive}
                    onChange={(event) =>
                      form.updateCondition(index, "caseSensitive", event.target.checked)
                    }
                  />
                  case sensitive
                </label>

                <button
                  type="button"
                  onClick={() => form.removeCondition(index)}
                  disabled={form.data.conditions.length <= 1}
                  className="rounded border border-slate-300 px-3 py-1 text-xs text-slate-700 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold">Actions</h2>
            <button
              type="button"
              onClick={form.addAction}
              className="rounded bg-slate-200 px-3 py-2 text-sm font-medium text-slate-800 hover:bg-slate-300"
            >
              Add action
            </button>
          </div>

          <div className="space-y-3">
            {form.data.actions.map((action, index) => {
              const requiresLabel = actionRequiresLabel(action.type);
              return (
                <div
                  key={`action-${index}`}
                  className="grid gap-2 rounded border border-slate-200 bg-slate-50 p-3 md:grid-cols-[1fr_2fr_auto]"
                >
                  <select
                    value={action.type}
                    onChange={(event) => form.updateAction(index, "type", event.target.value)}
                    className="rounded border border-slate-300 px-2 py-1"
                  >
                    {ACTION_TYPES.map((type) => (
                      <option key={type} value={type}>
                        {type}
                      </option>
                    ))}
                  </select>

                  <input
                    type="text"
                    value={action.label}
                    onChange={(event) => form.updateAction(index, "label", event.target.value)}
                    required={requiresLabel}
                    disabled={!requiresLabel}
                    placeholder="Label name (only for add/remove label)"
                    className={`rounded border border-slate-300 px-2 py-1 ${
                      requiresLabel ? "" : "bg-slate-100 text-slate-400"
                    }`}
                  />

                  <button
                    type="button"
                    onClick={() => form.removeAction(index)}
                    disabled={form.data.actions.length <= 1}
                    className="rounded border border-slate-300 px-3 py-1 text-xs text-slate-700 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Remove
                  </button>
                </div>
              );
            })}
          </div>
        </section>

        <div className="flex flex-wrap gap-3">
          <button
            type="submit"
            value="save"
            disabled={form.processing}
            className="rounded bg-sky-600 px-4 py-2 text-sm font-semibold text-white hover:bg-sky-700 disabled:cursor-not-allowed disabled:opacity-70"
          >
            Save
          </button>
          <button
            type="submit"
            value="save_and_apply"
            disabled={form.processing}
            className="rounded bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-70"
          >
            Save and apply rule
          </button>
        </div>
      </form>
    </>
  );
}
