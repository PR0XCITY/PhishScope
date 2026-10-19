import type { Table } from "../lib/data";
import { formatCell } from "../lib/text";

export function DataTable({ table }: { table: Table }) {
  return (
    <figure className="card overflow-hidden">
      <figcaption className="border-b border-border px-4 py-3 text-sm font-medium">{table.title}</figcaption>
      <div className="max-h-96 overflow-auto" tabIndex={0} aria-label={table.title}>
        <table className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10 bg-surface-2">
            <tr>
              {table.columns.map((c) => (
                <th
                  key={c}
                  scope="col"
                  className="num whitespace-nowrap px-3 py-2 text-left text-xs font-medium text-muted"
                >
                  {c}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {table.rows.map((row, i) => (
              <tr key={i} className="border-t border-border">
                {row.map((cell, j) => (
                  <td
                    key={j}
                    className={
                      "num whitespace-nowrap px-3 py-1.5 " +
                      (typeof cell === "number" ? "text-right" : "text-left")
                    }
                  >
                    {formatCell(cell)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </figure>
  );
}
