import { Head } from "@inertiajs/react";
import { useRef, useState } from "react";

function withPriorities(rules) {
  return rules.map((rule, index) => ({ ...rule, priority: index + 1 }));
}

function FiltersBadge({ count }) {
  return (
    <span className="inline-flex items-center px-2 py-1 bg-surface-container-high rounded text-[11px] font-semibold text-on-surface">
      {count} {count === 1 ? "Filter" : "Filters"}
    </span>
  );
}

function ActionsBadge({ count }) {
  return (
    <span className="inline-flex items-center px-2 py-1 bg-surface-container-high rounded text-[11px] font-semibold text-on-surface">
      {count} {count === 1 ? "Action" : "Actions"}
    </span>
  );
}

export default function RulesIndex({ activeRules, inactiveRules, reorderUrl }) {
  const [activeRulesState, setActiveRulesState] = useState(activeRules);
  const [draggingRuleId, setDraggingRuleId] = useState(null);
  const [status, setStatus] = useState(null);
  const draggedRuleIdRef = useRef(null);
  const csrfToken =
    document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || "";

  const persistOrder = async () => {
    const orderedIds = activeRulesState.map((rule) => rule.id);

    try {
      const response = await fetch(reorderUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": csrfToken,
        },
        body: JSON.stringify({ ordered_ids: orderedIds }),
      });

      if (!response.ok) {
        const payload = await response.json().catch(() => ({ error: "Unexpected error" }));
        throw new Error(payload.error || "Failed to reorder rules");
      }

      setStatus({ message: "Priority order saved", type: "success" });
    } catch (error) {
      setStatus({
        message: `Could not save priority order: ${error.message}`,
        type: "error",
      });
    }
  };

  const handleDragStart = (event, ruleId) => {
    draggedRuleIdRef.current = ruleId;
    setDraggingRuleId(ruleId);
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", ruleId);
  };

  const handleDragOver = (event, targetRuleId) => {
    event.preventDefault();
    const draggedRuleId = draggedRuleIdRef.current;

    if (!draggedRuleId || draggedRuleId === targetRuleId) return;

    const rowRect = event.currentTarget.getBoundingClientRect();
    const shouldInsertAfter = event.clientY > rowRect.top + rowRect.height / 2;

    setActiveRulesState((rules) => {
      const sourceIndex = rules.findIndex((rule) => rule.id === draggedRuleId);
      const targetIndex = rules.findIndex((rule) => rule.id === targetRuleId);

      if (sourceIndex === -1 || targetIndex === -1) return rules;

      let nextIndex = targetIndex + (shouldInsertAfter ? 1 : 0);
      if (sourceIndex < nextIndex) nextIndex -= 1;
      if (sourceIndex === nextIndex) return rules;

      const reordered = [...rules];
      const [moved] = reordered.splice(sourceIndex, 1);
      reordered.splice(nextIndex, 0, moved);

      return withPriorities(reordered);
    });
  };

  const handleDrop = async (event) => {
    event.preventDefault();
    if (!draggedRuleIdRef.current) return;
    draggedRuleIdRef.current = null;
    setDraggingRuleId(null);
    await persistOrder();
  };

  const handleDragEnd = () => {
    draggedRuleIdRef.current = null;
    setDraggingRuleId(null);
  };

  return (
    <>
      <Head title="Rules" />

      {status ? (
        <div
          className={`mb-6 px-6 py-4 rounded-xl flex items-center justify-between shadow-sm ${
            status.type === "success"
              ? "bg-secondary-container text-on-secondary-container border border-secondary/10"
              : "bg-error-container text-on-surface"
          }`}
        >
          <div className="flex items-center gap-3">
            <span
              className={`material-symbols-outlined ${
                status.type === "success" ? "text-secondary" : "text-error"
              }`}
            >
              {status.type === "success" ? "check_circle" : "error"}
            </span>
            <span className="font-medium text-sm">{status.message}</span>
          </div>
          <button
            onClick={() => setStatus(null)}
            className="text-on-surface/40 hover:text-on-surface transition-colors"
          >
            <span className="material-symbols-outlined text-lg">close</span>
          </button>
        </div>
      ) : null}

      <div className="flex items-end justify-between mb-8">
        <div>
          <h1 className="text-4xl font-extrabold tracking-tight text-on-surface mb-2">
            Automation Rules
          </h1>
          <p className="text-on-surface-variant max-w-2xl">
            Rules are processed in the order displayed below. Drag to reprioritize.
          </p>
        </div>
      </div>

      {/* Active Rules */}
      <section className="mb-16">
        <div className="flex items-center gap-3 mb-6">
          <h2 className="text-lg font-bold text-on-surface">Active Rules</h2>
          <span className="bg-secondary-fixed text-on-secondary-fixed px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider">
            {activeRulesState.length} Total
          </span>
        </div>

        <div className="bg-surface-container-lowest rounded-2xl overflow-hidden shadow-sm">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-surface-container-low text-on-surface-variant text-[11px] font-bold uppercase tracking-widest">
                <th className="pl-6 py-4 w-12"></th>
                <th className="px-4 py-4">Rule Name</th>
                <th className="px-4 py-4">Conditions</th>
                <th className="px-4 py-4">Actions</th>
                <th className="px-4 py-4">Times Applied</th>
                <th className="pr-6 py-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody
              className="divide-y divide-surface-container"
              onDrop={handleDrop}
              onDragOver={(event) => event.preventDefault()}
            >
              {activeRulesState.map((rule) => (
                <tr
                  key={rule.id}
                  draggable
                  onDragStart={(event) => handleDragStart(event, rule.id)}
                  onDragEnd={handleDragEnd}
                  onDragOver={(event) => handleDragOver(event, rule.id)}
                  className={`group hover:bg-surface-container-low transition-colors cursor-move ${
                    draggingRuleId === rule.id ? "opacity-50" : ""
                  }`}
                >
                  <td className="pl-6 py-5">
                    <span className="material-symbols-outlined text-outline-variant opacity-0 group-hover:opacity-100 transition-opacity select-none">
                      drag_indicator
                    </span>
                  </td>
                  <td className="px-4 py-5">
                    <span className="font-bold text-on-surface text-sm">{rule.name}</span>
                  </td>
                  <td className="px-4 py-5">
                    <FiltersBadge count={rule.conditionsCount} />
                  </td>
                  <td className="px-4 py-5">
                    <ActionsBadge count={rule.actionsCount} />
                  </td>
                  <td className="px-4 py-5 font-medium text-sm tabular-nums text-on-surface-variant">
                    {rule.applicationsCount}
                  </td>
                  <td className="pr-6 py-5 text-right space-x-1">
                    <a
                      href={rule.showUrl}
                      aria-label={`Show ${rule.name}`}
                      className="inline-flex p-2 hover:bg-surface-container-highest rounded-lg text-on-surface-variant hover:text-on-surface transition-all"
                    >
                      <span className="material-symbols-outlined text-xl">visibility</span>
                    </a>
                    <a
                      href={rule.editUrl}
                      aria-label={`Edit ${rule.name}`}
                      className="inline-flex p-2 hover:bg-surface-container-highest rounded-lg text-on-surface-variant hover:text-on-surface transition-all"
                    >
                      <span className="material-symbols-outlined text-xl">edit</span>
                    </a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Inactive Rules */}
      {inactiveRules.length > 0 ? (
        <section className="opacity-60 transition-opacity hover:opacity-100">
          <div className="flex items-center gap-3 mb-6">
            <h2 className="text-lg font-bold text-on-surface-variant">Inactive Rules</h2>
            <span className="bg-surface-container-high text-on-surface-variant px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider">
              {inactiveRules.length} Total
            </span>
          </div>

          <div className="bg-surface-container-low rounded-2xl overflow-hidden border border-surface-container border-dashed">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="text-on-surface-variant text-[11px] font-bold uppercase tracking-widest">
                  <th className="pl-6 py-4 w-12"></th>
                  <th className="px-4 py-4">Rule Name</th>
                  <th className="px-4 py-4">Conditions</th>
                  <th className="px-4 py-4">Actions</th>
                  <th className="px-4 py-4">Times Applied</th>
                  <th className="pr-6 py-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {inactiveRules.map((rule) => (
                  <tr key={rule.id} className="group">
                    <td className="pl-6 py-5">
                      <span className="material-symbols-outlined text-outline-variant">lock</span>
                    </td>
                    <td className="px-4 py-5">
                      <span className="font-bold text-on-surface-variant text-sm italic">
                        {rule.name}
                      </span>
                    </td>
                    <td className="px-4 py-5">
                      <span className="inline-flex items-center px-2 py-1 bg-surface-container rounded text-[11px] font-medium text-outline">
                        {rule.conditionsCount} {rule.conditionsCount === 1 ? "Filter" : "Filters"}
                      </span>
                    </td>
                    <td className="px-4 py-5">
                      <span className="inline-flex items-center px-2 py-1 bg-surface-container rounded text-[11px] font-medium text-outline">
                        {rule.actionsCount} {rule.actionsCount === 1 ? "Action" : "Actions"}
                      </span>
                    </td>
                    <td className="px-4 py-5 font-medium text-sm tabular-nums text-outline">
                      {rule.applicationsCount}
                    </td>
                    <td className="pr-6 py-5 text-right space-x-1">
                      <a
                        href={rule.showUrl}
                        aria-label={`Show ${rule.name}`}
                        className="inline-flex p-2 hover:bg-surface-container-highest rounded-lg text-on-surface-variant transition-all"
                      >
                        <span className="material-symbols-outlined text-xl">visibility</span>
                      </a>
                      <a
                        href={rule.editUrl}
                        aria-label={`Edit ${rule.name}`}
                        className="inline-flex p-2 hover:bg-surface-container-highest rounded-lg text-on-surface-variant transition-all"
                      >
                        <span className="material-symbols-outlined text-xl">edit</span>
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}
    </>
  );
}
