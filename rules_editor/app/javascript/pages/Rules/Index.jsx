import { Head } from "@inertiajs/react";
import { useRef, useState } from "react";

function statusClasses(type) {
  if (type === "success") {
    return "border-emerald-300 bg-emerald-50 text-emerald-800";
  }

  return "border-rose-300 bg-rose-50 text-rose-800";
}

function withPriorities(rules) {
  return rules.map((rule, index) => ({ ...rule, priority: index + 1 }));
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

    if (!draggedRuleId || draggedRuleId === targetRuleId) {
      return;
    }

    const rowRect = event.currentTarget.getBoundingClientRect();
    const shouldInsertAfter = event.clientY > rowRect.top + rowRect.height / 2;

    setActiveRulesState((rules) => {
      const sourceIndex = rules.findIndex((rule) => rule.id === draggedRuleId);
      const targetIndex = rules.findIndex((rule) => rule.id === targetRuleId);

      if (sourceIndex === -1 || targetIndex === -1) {
        return rules;
      }

      let nextIndex = targetIndex + (shouldInsertAfter ? 1 : 0);
      if (sourceIndex < nextIndex) {
        nextIndex -= 1;
      }

      if (sourceIndex === nextIndex) {
        return rules;
      }

      const reordered = [...rules];
      const [moved] = reordered.splice(sourceIndex, 1);
      reordered.splice(nextIndex, 0, moved);

      return withPriorities(reordered);
    });
  };

  const handleDrop = async (event) => {
    event.preventDefault();
    if (!draggedRuleIdRef.current) {
      return;
    }

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

      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Rules</h1>
          <p className="text-sm text-slate-600">
            Drag and drop active rules to update priority. Priority 1 runs first.
          </p>
        </div>
      </div>

      <div
        className={`mb-4 rounded border px-4 py-2 text-sm ${
          status ? statusClasses(status.type) : "hidden"
        }`}
      >
        {status?.message}
      </div>

      <div className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50 text-left text-slate-700">
            <tr>
              <th className="px-4 py-3">Priority</th>
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">Conditions</th>
              <th className="px-4 py-3">Actions</th>
              <th className="px-4 py-3 text-right">Links</th>
            </tr>
          </thead>
          <tbody
            className="divide-y divide-slate-100"
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
                className={`cursor-move bg-white transition hover:bg-sky-50 ${
                  draggingRuleId === rule.id ? "opacity-50" : ""
                }`}
              >
                <td className="px-4 py-3 font-mono">{rule.priority}</td>
                <td className="px-4 py-3 font-medium text-slate-900">{rule.name}</td>
                <td className="px-4 py-3 text-slate-600">{rule.conditionsCount}</td>
                <td className="px-4 py-3 text-slate-600">{rule.actionsCount}</td>
                <td className="px-4 py-3 text-right">
                  <a href={rule.showUrl} className="text-sky-700 hover:underline">
                    Show
                  </a>
                  <span className="px-1 text-slate-300">|</span>
                  <a href={rule.editUrl} className="text-sky-700 hover:underline">
                    Edit
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {inactiveRules.length > 0 ? (
        <>
          <h2 className="mb-3 mt-8 text-lg font-semibold">Inactive Rules</h2>
          <div className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 text-left text-slate-700">
                <tr>
                  <th className="px-4 py-3">Priority</th>
                  <th className="px-4 py-3">Name</th>
                  <th className="px-4 py-3 text-right">Links</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {inactiveRules.map((rule) => (
                  <tr key={rule.id} className="bg-slate-50">
                    <td className="px-4 py-3 font-mono text-slate-500">{rule.priority}</td>
                    <td className="px-4 py-3 text-slate-500">{rule.name}</td>
                    <td className="px-4 py-3 text-right">
                      <a href={rule.showUrl} className="text-sky-700 hover:underline">
                        Show
                      </a>
                      <span className="px-1 text-slate-300">|</span>
                      <a href={rule.editUrl} className="text-sky-700 hover:underline">
                        Edit
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      ) : null}
    </>
  );
}
