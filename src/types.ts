export interface FileNode {
  name: string;
  path: string;
  type: "file" | "directory";
  size?: number;
  children?: FileNode[];
}

export interface FlatFiles {
  [path: string]: string;
}

export interface ChatMessage {
  role: "user" | "model";
  text: string;
  timestamp: Date;
}

export interface PackageDetail {
  name: string;
  version: string;
  purpose: string;
  whyUsed: string;
}

export interface FolderResponsibility {
  path: string;
  name: string;
  purpose: string;
  layer: "presentation" | "domain" | "data" | "core";
  details: string[];
}
