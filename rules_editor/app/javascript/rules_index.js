function initializeRuleReordering() {
  const sortable = document.getElementById("rules-sortable");
  if (!sortable) return;

  const statusElement = document.getElementById("rules-reorder-status");
  const reorderUrl = sortable.dataset.reorderUrl;
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

  let draggedRow = null;

  const updateStatus = (message, success) => {
    if (!statusElement) return;

    statusElement.textContent = message;
    statusElement.classList.remove("hidden", "border-emerald-300", "bg-emerald-50", "text-emerald-800", "border-rose-300", "bg-rose-50", "text-rose-800");

    if (success) {
      statusElement.classList.add("border-emerald-300", "bg-emerald-50", "text-emerald-800");
    } else {
      statusElement.classList.add("border-rose-300", "bg-rose-50", "text-rose-800");
    }
  };

  const refreshPriorityCells = () => {
    const rows = sortable.querySelectorAll("tr[data-rule-id]");
    rows.forEach((row, index) => {
      const priorityCell = row.querySelector("td");
      if (priorityCell) priorityCell.textContent = String(index + 1);
    });
  };

  const persistOrder = async () => {
    const orderedIds = Array.from(sortable.querySelectorAll("tr[data-rule-id]")).map((row) => row.dataset.ruleId);

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

      updateStatus("Priority order saved", true);
    } catch (error) {
      updateStatus(`Could not save priority order: ${error.message}`, false);
    }
  };

  sortable.addEventListener("dragstart", (event) => {
    const row = event.target.closest("tr[data-rule-id]");
    if (!row) return;

    draggedRow = row;
    row.classList.add("opacity-50");
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", row.dataset.ruleId);
  });

  sortable.addEventListener("dragend", () => {
    if (draggedRow) draggedRow.classList.remove("opacity-50");
    draggedRow = null;
  });

  sortable.addEventListener("dragover", (event) => {
    event.preventDefault();
    const row = event.target.closest("tr[data-rule-id]");
    if (!row || !draggedRow || row === draggedRow) return;

    const rect = row.getBoundingClientRect();
    const shouldInsertAfter = event.clientY > rect.top + rect.height / 2;

    if (shouldInsertAfter) {
      sortable.insertBefore(draggedRow, row.nextSibling);
    } else {
      sortable.insertBefore(draggedRow, row);
    }
  });

  sortable.addEventListener("drop", async (event) => {
    event.preventDefault();
    if (!draggedRow) return;

    refreshPriorityCells();
    await persistOrder();
  });
}

document.addEventListener("DOMContentLoaded", initializeRuleReordering);
