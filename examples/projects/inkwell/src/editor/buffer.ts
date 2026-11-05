// Piece-table text buffer: the original text plus an append-only add buffer.
export interface Piece { source: "original" | "add"; start: number; length: number }

export class PieceTable {
  private pieces: Piece[] = [];
  private add = "";
  constructor(private original: string) {
    this.pieces.push({ source: "original", start: 0, length: original.length });
  }
  insert(text: string): void {
    this.pieces.push({ source: "add", start: this.add.length, length: text.length });
    this.add += text;
  }
  toString(): string {
    return this.pieces
      .map((p) => (p.source === "original" ? this.original : this.add).slice(p.start, p.start + p.length))
      .join("");
  }
}
