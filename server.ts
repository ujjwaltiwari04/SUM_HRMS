import express from "express";
import path from "path";
import fs from "fs";
import { GoogleGenAI } from "@google/genai";
import { createServer as createViteServer } from "vite";
import dotenv from "dotenv";

dotenv.config();

const app = express();
const PORT = 3000;

app.use(express.json());

// Initialize server-side Gemini API client
const apiKey = process.env.GEMINI_API_KEY;
let ai: GoogleGenAI | null = null;

if (apiKey) {
  ai = new GoogleGenAI({
    apiKey: apiKey,
    httpOptions: {
      headers: {
        "User-Agent": "aistudio-build",
      },
    },
  });
}

// ----------------------------------------------------------------------
// BACKEND API ROUTES (MUST go BEFORE Vite middleware)
// ----------------------------------------------------------------------

// 1. Health check
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", gemini_initialized: !!ai });
});

// Helper: Recursively walk a directory
function walkDir(dir: string, baseDir: string = dir): any[] {
  let results: any[] = [];
  try {
    const list = fs.readdirSync(dir);
    list.forEach((file) => {
      const fullPath = path.join(dir, file);
      const relativePath = path.relative(baseDir, fullPath);
      const stat = fs.statSync(fullPath);
      if (stat && stat.isDirectory()) {
        results.push({
          name: file,
          path: relativePath,
          type: "directory",
          children: walkDir(fullPath, baseDir),
        });
      } else {
        results.push({
          name: file,
          path: relativePath,
          type: "file",
          size: stat.size,
        });
      }
    });
  } catch (error) {
    console.error("Error reading dir: ", dir, error);
  }
  return results;
}

// Helper: Read file contents recursively
function getFlatFiles(dir: string, baseDir: string = dir): { [path: string]: string } {
  const flat: { [path: string]: string } = {};
  function recurse(currentDir: string) {
    const list = fs.readdirSync(currentDir);
    list.forEach((file) => {
      const fullPath = path.join(currentDir, file);
      const relativePath = path.relative(baseDir, fullPath);
      const stat = fs.statSync(fullPath);
      if (stat && stat.isDirectory()) {
        recurse(fullPath);
      } else {
        try {
          const content = fs.readFileSync(fullPath, "utf-8");
          flat[relativePath] = content;
        } catch (e) {
          flat[relativePath] = `[Binary or unreadable file: ${file}]`;
        }
      }
    });
  }
  try {
    recurse(dir);
  } catch (e) {
    console.error("Error building flat files dictionary", e);
  }
  return flat;
}

// 2. Fetch the Flutter Clean Architecture directory tree
app.get("/api/files", (req, res) => {
  const flutterDir = path.join(process.cwd(), "sum_enterprises");
  if (!fs.existsSync(flutterDir)) {
    return res.status(404).json({ error: "Flutter directory sum_enterprises not found" });
  }
  const tree = walkDir(flutterDir);
  res.json({ tree });
});

// 3. Fetch single file contents
app.get("/api/file", (req, res) => {
  const relPath = req.query.path as string;
  if (!relPath) {
    return res.status(400).json({ error: "Missing path parameter" });
  }
  // Prevent directory traversal attacks
  const normalizedPath = path.normalize(relPath).replace(/^(\.\.(\/|\\|$))+/, "");
  const fullPath = path.join(process.cwd(), "sum_enterprises", normalizedPath);

  if (!fs.existsSync(fullPath)) {
    return res.status(404).json({ error: `File not found: ${relPath}` });
  }

  try {
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      return res.status(400).json({ error: "Requested path is a directory, not a file." });
    }
    const content = fs.readFileSync(fullPath, "utf-8");
    res.json({ path: relPath, content });
  } catch (err) {
    res.status(500).json({ error: "Failed to read file contents." });
  }
});

// 4. Fetch flat files list (useful for client-side download as ZIP)
app.get("/api/files/flat", (req, res) => {
  const flutterDir = path.join(process.cwd(), "sum_enterprises");
  if (!fs.existsSync(flutterDir)) {
    return res.status(404).json({ error: "Flutter directory not found" });
  }
  const files = getFlatFiles(flutterDir);
  res.json({ files });
});

// 5. AI Assistant endpoint for explaining and generating clean architecture extensions
app.post("/api/assistant", async (req, res) => {
  const { prompt, chatHistory } = req.body;
  if (!prompt) {
    return res.status(400).json({ error: "Prompt is required." });
  }

  if (!ai) {
    return res.status(503).json({
      error: "Gemini API client is not initialized. Please verify your GEMINI_API_KEY in the Settings > Secrets menu.",
    });
  }

  try {
    const systemInstruction = `You are the Lead Flutter Software Architect and Firebase Expert for SUM ENTERPRISES.
The company is a private field service enterprise with maximum 6 employees plus 1 administrator.

You are assisting developers working on the Dart/Flutter mobile application based on a strictly decoupled Clean Architecture foundation.
Key architectural principles:
- Enforce strict separation of concerns (Data -> Domain <- Presentation).
- Presentation layer: widgets and Riverpod state managers (Notifiers/StreamProviders).
- Domain layer: Entities/Models, use cases (optional but recommended for logic), and repository interface contracts.
- Data layer: repository implementations, datasources (Firebase Auth, Cloud Firestore, Firebase Storage).
- The primary brand colors are: Copper Brown (#8B4513) and Warm Brown (#A05A2C).
- Visual elements must follow Google's Material 3 standard: minimalist, lightweight, 14px rounded corners, soft shadows.

Provide beautifully styled Dart/Flutter code blocks that fit directly into this folder structure.
Do not use mock libraries. Use flutter_riverpod, go_router, cloud_firestore, firebase_auth, and google_maps_flutter.
Be extremely professional, encouraging, and accurate. When outputting code, specify the complete file path at the top of the code snippet.`;

    const contents = [
      ...(chatHistory || []).map((h: any) => ({
        role: h.role,
        parts: [{ text: h.text }],
      })),
      { role: "user", parts: [{ text: prompt }] },
    ];

    const response = await ai.models.generateContent({
      model: "gemini-3.5-flash",
      contents: contents,
      config: {
        systemInstruction,
        temperature: 0.3,
      },
    });

    res.json({ text: response.text });
  } catch (error: any) {
    console.error("Gemini API Error:", error);
    res.status(500).json({ error: error.message || "An error occurred with the AI model generation." });
  }
});

// ----------------------------------------------------------------------
// VITE OR STATIC FILE SERVING MIDDLEWARE
// ----------------------------------------------------------------------
async function startServer() {
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server successfully started on http://0.0.0.0:${PORT}`);
  });
}

startServer();
