import { Head } from "@inertiajs/react";

function actionIcon(type) {
  switch (type) {
    case "add_label":
    case "remove_label":
      return "label";
    case "mark_read":
      return "drafts";
    case "trash":
      return "delete";
    default:
      return "bolt";
  }
}

function actionLabel(type) {
  switch (type) {
    case "add_label":
      return "Apply Label";
    case "remove_label":
      return "Remove Label";
    case "mark_read":
      return "Mark as Read";
    case "trash":
      return "Trash";
    default:
      return type;
  }
}

export default function RulesShow({ rule, matchingEmails, gmailPreview }) {
  const previewEmails = gmailPreview?.emails || [];
  const matchedEmails = matchingEmails?.emails || [];

  return (
    <>
      <Head title={rule.name} />

      {/* Page Header */}
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-10">
        <div>
          <a
            href={rule.backUrl}
            className="inline-flex items-center gap-1 text-sm font-medium text-on-surface-variant hover:text-primary transition-colors mb-4"
          >
            <span className="material-symbols-outlined text-sm">arrow_back</span>
            Back to Rules
          </a>
          <div className="flex flex-wrap items-center gap-3 mb-2">
            <h1 className="text-4xl font-extrabold tracking-tight text-on-surface">
              {rule.name}
            </h1>
            <span
              className={`px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider ${
                rule.active
                  ? "bg-secondary-container text-on-secondary-container"
                  : "bg-surface-container-high text-on-surface-variant"
              }`}
            >
              {rule.active ? "Active" : "Inactive"}
            </span>
          </div>
          <div className="flex items-center gap-3">
            <span className="bg-surface-container-highest text-on-surface-variant px-2.5 py-0.5 rounded-lg text-sm font-semibold">
              Priority #{rule.priority}
            </span>
          </div>
        </div>
        <div className="flex gap-3">
          <a
            href={rule.editUrl}
            className="inline-flex items-center gap-2 px-6 py-2.5 bg-primary text-on-primary font-semibold rounded-md shadow-sm hover:opacity-90 transition-opacity text-sm"
          >
            <span className="material-symbols-outlined text-sm">edit</span>
            Edit Rule
          </a>
        </div>
      </header>

      {/* Main grid: Conditions+Actions (left) / Gmail Preview (right) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 mb-10">

        {/* Left column: Conditions + Actions */}
        <div className="lg:col-span-5 space-y-6">

          {/* Conditions */}
          <div className="bg-surface-container-lowest rounded-xl p-8 shadow-sm">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-lg font-bold flex items-center gap-2 text-on-surface">
                <span className="material-symbols-outlined text-primary">filter_alt</span>
                Conditions
              </h2>
              <span className="text-xs font-bold text-on-surface-variant uppercase tracking-widest bg-surface-container px-2 py-1 rounded">
                Match {rule.matchMode === "all" ? "All (AND)" : "Any (OR)"}
              </span>
            </div>
            <div className="space-y-3">
              {rule.conditions.map((condition, index) => (
                <div
                  key={`${condition.field}-${condition.operator}-${index}`}
                  className="flex items-center gap-4 p-4 rounded-lg bg-surface-container-low border-l-4 border-primary"
                >
                  <div className="flex-1">
                    <p className="text-xs font-bold text-on-surface-variant uppercase tracking-tighter mb-1">
                      {condition.field}
                    </p>
                    <p className="text-on-surface font-medium text-sm">
                      {condition.operator}{" "}
                      <span className="text-primary font-bold">{condition.value}</span>
                      {condition.caseSensitive ? (
                        <span className="ml-2 text-[11px] text-on-surface-variant font-normal">
                          (case-sensitive)
                        </span>
                      ) : null}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Actions */}
          <div className="bg-surface-container-lowest rounded-xl p-8 shadow-sm">
            <h2 className="text-lg font-bold flex items-center gap-2 mb-6 text-on-surface">
              <span className="material-symbols-outlined text-secondary">bolt</span>
              Actions
            </h2>
            <div className="space-y-3">
              {rule.actions.map((action, index) => (
                <div
                  key={`${action.type}-${index}`}
                  className="flex items-center gap-4 p-4 rounded-lg bg-surface-container-low"
                >
                  <span className="material-symbols-outlined text-on-surface-variant bg-white p-2 rounded-md shadow-sm">
                    {actionIcon(action.type)}
                  </span>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-on-surface-variant uppercase tracking-tighter mb-0.5">
                      {actionLabel(action.type)}
                    </p>
                    {action.label ? (
                      <p className="text-on-surface font-semibold text-sm">{action.label}</p>
                    ) : null}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Right column: Gmail Impact Preview */}
        <section className="lg:col-span-7 bg-surface-container-lowest rounded-xl shadow-sm overflow-hidden flex flex-col">
          <div className="p-8 border-b border-surface-container">
            <div className="flex items-center justify-between mb-2">
              <h2 className="text-xl font-extrabold flex items-center gap-2 text-on-surface">
                <span className="material-symbols-outlined text-primary-dim">preview</span>
                Live Gmail Impact Preview
              </h2>
              <span className="text-xs font-medium text-secondary flex items-center gap-1">
                <span className="w-2 h-2 rounded-full bg-secondary inline-block"></span>
                Live Connection
              </span>
            </div>
            <p className="text-on-surface-variant text-sm">
              Showing the most recent emails that would be affected by this rule.
              {gmailPreview.totalCount > 0
                ? ` ${gmailPreview.totalCount} match${gmailPreview.totalCount === 1 ? "" : "es"} found across ${gmailPreview.scannedCount} scanned messages.`
                : ` Scanned ${gmailPreview.scannedCount} recent inbox messages.`}
            </p>
            {gmailPreview.error ? (
              <p className="mt-3 px-3 py-2 rounded-lg bg-error-container text-on-surface text-sm">
                {gmailPreview.error}
              </p>
            ) : null}
          </div>

          {previewEmails.length > 0 ? (
            <div className="flex-1 overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-surface-container-low">
                    <th className="px-8 py-4 text-xs font-bold text-on-surface-variant uppercase tracking-widest">
                      Sender
                    </th>
                    <th className="px-8 py-4 text-xs font-bold text-on-surface-variant uppercase tracking-widest">
                      Subject
                    </th>
                    <th className="px-8 py-4 text-xs font-bold text-on-surface-variant uppercase tracking-widest">
                      Date
                    </th>
                    <th className="px-8 py-4 text-xs font-bold text-on-surface-variant uppercase tracking-widest text-right">
                      Open
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-surface-container">
                  {previewEmails.map((email, index) => (
                    <tr
                      key={`${email.gmailUrl}-${index}`}
                      className="hover:bg-surface-container-low transition-colors"
                    >
                      <td className="px-8 py-5">
                        <p className="text-sm font-bold text-on-surface">{email.from}</p>
                      </td>
                      <td className="px-8 py-5">
                        <p className="text-sm font-medium text-on-surface line-clamp-1">
                          {email.subject}
                        </p>
                      </td>
                      <td className="px-8 py-5 text-sm text-on-surface-variant whitespace-nowrap">
                        {email.date}
                      </td>
                      <td className="px-8 py-5 text-right">
                        <a
                          href={email.gmailUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center text-primary-dim hover:text-primary transition-colors"
                        >
                          <span className="material-symbols-outlined text-lg">open_in_new</span>
                        </a>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="flex-1 flex items-center justify-center p-8">
              <p className="text-sm text-on-surface-variant">
                No inbox emails would be affected by this rule right now.
              </p>
            </div>
          )}

          {gmailPreview.truncated ? (
            <div className="p-6 bg-surface-container-low/50 flex justify-center border-t border-surface-container">
              <p className="text-sm text-on-surface-variant">
                Showing first {previewEmails.length} of {gmailPreview.totalCount} matches.
              </p>
            </div>
          ) : null}
        </section>
      </div>

      {/* Match History */}
      <section className="bg-surface-container-lowest rounded-xl shadow-sm p-8">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <div>
            <h2 className="text-2xl font-extrabold tracking-tight text-on-surface">
              Match History
            </h2>
            <p className="text-on-surface-variant text-sm mt-1">
              Audit log of actions previously executed by this rule.
              {matchingEmails.totalCount > 0 ? ` ${matchingEmails.totalCount} total.` : ""}
            </p>
          </div>
        </div>

        {matchingEmails.error ? (
          <p className="mb-4 px-4 py-3 rounded-lg bg-error-container text-on-surface text-sm">
            Some email details could not be loaded from Gmail: {matchingEmails.error}
          </p>
        ) : null}

        {matchedEmails.length > 0 ? (
          <div className="space-y-3">
            {matchedEmails.map((email, index) => (
              <div
                key={`${email.gmailUrl}-${index}`}
                className="grid grid-cols-12 gap-4 items-center p-4 rounded-lg bg-surface border-l-4 border-secondary/40 hover:translate-x-1 transition-transform"
              >
                <div className="col-span-1 flex justify-center">
                  <span
                    className="material-symbols-outlined text-secondary"
                    style={{ fontVariationSettings: "'FILL' 1" }}
                  >
                    check_circle
                  </span>
                </div>
                <div className="col-span-4">
                  <p className="text-sm font-bold text-on-surface">{email.subject}</p>
                  <p className="text-[11px] text-on-surface-variant">{email.from}</p>
                </div>
                <div className="col-span-4 flex flex-wrap gap-1">
                  {email.actions?.map((action, ai) => (
                    <span
                      key={ai}
                      className="px-2 py-0.5 rounded bg-secondary-container text-[10px] font-bold text-on-secondary-container uppercase"
                    >
                      {action}
                    </span>
                  ))}
                </div>
                <div className="col-span-2 text-sm text-on-surface-variant whitespace-nowrap">
                  {email.date}
                </div>
                <div className="col-span-1 text-right">
                  <a
                    href={email.gmailUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-on-surface-variant hover:text-primary transition-colors text-xs font-bold"
                  >
                    Details
                  </a>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-sm text-on-surface-variant">No emails have matched this rule yet.</p>
        )}

        {matchingEmails.truncated ? (
          <div className="mt-6 pt-6 border-t border-surface-container">
            <p className="text-xs text-on-surface-variant font-medium">
              Showing {matchedEmails.length} of {matchingEmails.totalCount} matching emails.
            </p>
          </div>
        ) : null}
      </section>
    </>
  );
}
