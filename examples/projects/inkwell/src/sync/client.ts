// Sync client: pushes document revisions to a self-hosted server the user configures.
export async function pushRevision(serverUrl: string, docId: string, body: string): Promise<void> {
  await fetch(`${serverUrl}/docs/${encodeURIComponent(docId)}`, { method: "PUT", body });
}
