function initializeRuleEditorForm() {
  const conditionsContainer = document.getElementById("conditions-container");
  const actionsContainer = document.getElementById("actions-container");
  if (!conditionsContainer || !actionsContainer) return;

  const conditionTemplate = document.getElementById("condition-row-template");
  const actionTemplate = document.getElementById("action-row-template");

  const addConditionButton = document.getElementById("add-condition");
  const addActionButton = document.getElementById("add-action");

  const nextIndex = (container) => {
    const current = Number(container.dataset.nextIndex || "0");
    container.dataset.nextIndex = String(current + 1);
    return current;
  };

  const templateWithIndex = (template, index) => {
    const wrapper = document.createElement("div");
    wrapper.innerHTML = template.innerHTML.replaceAll("__INDEX__", String(index));
    return wrapper.firstElementChild;
  };

  const toggleLabelInput = (row) => {
    const typeSelect = row.querySelector(".action-type");
    const labelInput = row.querySelector(".action-label");
    if (!typeSelect || !labelInput) return;

    const requiresLabel = typeSelect.value === "add_label" || typeSelect.value === "remove_label";
    labelInput.disabled = !requiresLabel;
    labelInput.required = requiresLabel;

    if (!requiresLabel) {
      labelInput.value = "";
      labelInput.classList.add("bg-slate-100", "text-slate-400");
    } else {
      labelInput.classList.remove("bg-slate-100", "text-slate-400");
    }
  };

  const removeRow = (button) => {
    const row = button.closest(".condition-row, .action-row");
    if (!row) return;

    const isCondition = row.classList.contains("condition-row");
    const container = isCondition ? conditionsContainer : actionsContainer;
    const selector = isCondition ? ".condition-row" : ".action-row";

    if (container.querySelectorAll(selector).length <= 1) return;
    row.remove();
  };

  addConditionButton?.addEventListener("click", () => {
    if (!conditionTemplate) return;

    const index = nextIndex(conditionsContainer);
    const row = templateWithIndex(conditionTemplate, index);
    if (!row) return;

    conditionsContainer.appendChild(row);
  });

  addActionButton?.addEventListener("click", () => {
    if (!actionTemplate) return;

    const index = nextIndex(actionsContainer);
    const row = templateWithIndex(actionTemplate, index);
    if (!row) return;

    actionsContainer.appendChild(row);
    toggleLabelInput(row);
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest(".remove-row");
    if (!button) return;

    removeRow(button);
  });

  actionsContainer.addEventListener("change", (event) => {
    const typeSelect = event.target.closest(".action-type");
    if (!typeSelect) return;

    const row = typeSelect.closest(".action-row");
    if (!row) return;

    toggleLabelInput(row);
  });

  actionsContainer.querySelectorAll(".action-row").forEach((row) => {
    toggleLabelInput(row);
  });
}

document.addEventListener("DOMContentLoaded", initializeRuleEditorForm);
