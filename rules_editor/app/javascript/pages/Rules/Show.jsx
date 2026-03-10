import { Head } from "@inertiajs/react";

export default function RulesShow({ rule, matchingEmails, gmailPreview }) {
  const previewEmails = gmailPreview?.emails || [];
  const matchedEmails = matchingEmails?.emails || [];

  return (
    <>
      <Head title={rule.name} />

      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">{rule.name}</h1>
          <p className="text-sm text-slate-600">
            Priority <span className="font-mono">{rule.priority}</span> •{" "}
            {rule.active ? "Active" : "Inactive"}
          </p>
        </div>
        <div className="space-x-3 text-sm">
          <a
            href={rule.editUrl}
            className="rounded bg-sky-600 px-3 py-2 font-medium text-white hover:bg-sky-700"
          >
            Edit
          </a>
          <a
            href={rule.backUrl}
            className="rounded border border-slate-300 px-3 py-2 text-slate-700 hover:bg-slate-50"
          >
            Back
          </a>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <section className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <h2 className="mb-3 text-lg font-semibold">Conditions ({rule.matchMode})</h2>
          <ul className="space-y-2 text-sm">
            {rule.conditions.map((condition, index) => (
              <li
                key={`${condition.field}-${condition.operator}-${index}`}
                className="rounded border border-slate-200 bg-slate-50 px-3 py-2"
              >
                <span className="font-medium">{condition.field}</span>
                <span className="mx-1 text-slate-400">•</span>
                <span>{condition.operator}</span>
                <span className="mx-1 text-slate-400">•</span>
                <span className="font-mono">{condition.value}</span>
                <span className="ml-2 text-xs text-slate-500">
                  ({condition.caseSensitive ? "case-sensitive" : "case-insensitive"})
                </span>
              </li>
            ))}
          </ul>
        </section>

        <section className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <h2 className="mb-3 text-lg font-semibold">Actions</h2>
          <ul className="space-y-2 text-sm">
            {rule.actions.map((action, index) => (
              <li
                key={`${action.type}-${index}`}
                className="rounded border border-slate-200 bg-slate-50 px-3 py-2"
              >
                <span className="font-medium">{action.type}</span>
                {action.label ? (
                  <>
                    <span className="mx-1 text-slate-400">•</span>
                    <span className="font-mono">{action.label}</span>
                  </>
                ) : null}
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="mt-6 rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
        <div className="mb-3 flex items-start justify-between gap-4">
          <div>
            <h2 className="text-lg font-semibold">Gmail Impact Preview ({gmailPreview.totalCount})</h2>
            <p className="text-xs text-slate-500">
              Scanned {gmailPreview.scannedCount} recent inbox messages and found emails this rule
              would affect right now.
            </p>
          </div>

          {gmailPreview.truncated ? (
            <p className="text-xs text-slate-500">
              Showing the first {previewEmails.length} emails.
            </p>
          ) : null}
        </div>

        {gmailPreview.error ? (
          <p className="mb-3 rounded border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-800">
            Gmail preview could not be fully loaded: {gmailPreview.error}
          </p>
        ) : null}

        {previewEmails.length > 0 ? (
          <div className="overflow-x-auto rounded border border-slate-200">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 text-left text-slate-700">
                <tr>
                  <th className="px-4 py-3">Subject</th>
                  <th className="px-4 py-3">From</th>
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Planned Actions</th>
                  <th className="px-4 py-3 text-right">Details</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 bg-white">
                {previewEmails.map((email, index) => (
                  <tr key={`${email.gmailUrl}-${index}`}>
                    <td className="px-4 py-3 text-slate-900">{email.subject}</td>
                    <td className="px-4 py-3 text-slate-700">{email.from}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-slate-700">{email.date}</td>
                    <td className="px-4 py-3 text-slate-700">{email.actions.join(", ")}</td>
                    <td className="px-4 py-3 text-right">
                      <a
                        href={email.gmailUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-sky-700 hover:underline"
                      >
                        Open in Gmail
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-sm text-slate-600">
            No inbox emails would be affected by this rule right now.
          </p>
        )}
      </section>

      <section className="mt-6 rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
        <h2 className="mb-2 text-lg font-semibold">Metadata</h2>
        <pre className="overflow-x-auto rounded bg-slate-900 p-3 text-xs text-slate-100">
          {rule.metadata}
        </pre>
      </section>

      <section className="mt-6 rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold">Matched Emails ({matchingEmails.totalCount})</h2>
          {matchingEmails.truncated ? (
            <p className="text-xs text-slate-500">
              Showing the most recent {matchedEmails.length} matches.
            </p>
          ) : null}
        </div>

        {matchingEmails.error ? (
          <p className="mb-3 rounded border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-800">
            Some email details could not be loaded from Gmail: {matchingEmails.error}
          </p>
        ) : null}

        {matchedEmails.length > 0 ? (
          <div className="overflow-x-auto rounded border border-slate-200">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 text-left text-slate-700">
                <tr>
                  <th className="px-4 py-3">Subject</th>
                  <th className="px-4 py-3">From</th>
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3 text-right">Details</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 bg-white">
                {matchedEmails.map((email, index) => (
                  <tr key={`${email.gmailUrl}-${index}`}>
                    <td className="px-4 py-3 text-slate-900">{email.subject}</td>
                    <td className="px-4 py-3 text-slate-700">{email.from}</td>
                    <td className="whitespace-nowrap px-4 py-3 text-slate-700">{email.date}</td>
                    <td className="px-4 py-3 text-right">
                      <a
                        href={email.gmailUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-sky-700 hover:underline"
                      >
                        Open in Gmail
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-sm text-slate-600">No emails have matched this rule yet.</p>
        )}
      </section>
    </>
  );
}
