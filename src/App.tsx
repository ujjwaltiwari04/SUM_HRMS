import React, { useState, useEffect, useRef } from "react";
import {
  Folder,
  File,
  ChevronRight,
  ChevronDown,
  Copy,
  Check,
  Download,
  Sparkles,
  BookOpen,
  Palette,
  Search,
  ArrowRight,
  Send,
  Terminal,
  Info,
  Layers,
  Users,
  Building,
  CheckCircle,
  FileCode,
  MapPin,
  Cpu,
  RefreshCw,
} from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import JSZip from "jszip";
import { packagesData, foldersData, bestPracticesGuides, scalabilityPlan } from "./data";
import { FileNode, ChatMessage } from "./types";

export default function App() {
  // Navigation & Workspace State
  const [activeTab, setActiveTab] = useState<"explorer" | "visualizer">("explorer");
  const [rightPanelTab, setRightPanelTab] = useState<"assistant" | "branding" | "principles">("assistant");
  
  // File Explorer State
  const [fileTree, setFileTree] = useState<FileNode[]>([]);
  const [expandedNodes, setExpandedNodes] = useState<Record<string, boolean>>({
    "": true,
    "lib": true,
    "lib/core": true,
    "lib/features": true,
  });
  const [selectedFilePath, setSelectedFilePath] = useState<string>("pubspec.yaml");
  const [selectedFileContent, setSelectedFileContent] = useState<string>("");
  const [selectedFileDescription, setSelectedFileDescription] = useState<string>("");
  const [flatFiles, setFlatFiles] = useState<Record<string, string>>({});
  const [isLoadingFile, setIsLoadingFile] = useState(false);
  
  // Filtering & Search
  const [fileFilter, setFileFilter] = useState<"all" | "presentation" | "domain" | "data" | "core">("all");
  const [codeSearchQuery, setCodeSearchQuery] = useState("");
  const [copiedFile, setCopiedFile] = useState(false);
  const [isDownloading, setIsDownloading] = useState(false);

  // AI Assistant State
  const [chatMessages, setChatMessages] = useState<ChatMessage[]>([
    {
      role: "model",
      text: "Hello! I am your SUM ENTERPRISES Senior Flutter Software Architect. I've designed and provisioned this private corporate employee management foundation. How can I help you customize or extend this architecture today? (e.g., 'How do I add an Attendance model?' or 'Explain role-based routing')",
      timestamp: new Date(),
    },
  ]);
  const [chatInput, setChatInput] = useState("");
  const [isSendingToAI, setIsSendingToAI] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  // Load the initial file structure and first file (pubspec.yaml)
  useEffect(() => {
    fetchFileTree();
    fetchFlatFiles();
    fetchFileContent("pubspec.yaml");
  }, []);

  // Scroll to bottom of chat
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [chatMessages, isSendingToAI]);

  const fetchFileTree = async () => {
    try {
      const response = await fetch("/api/files");
      if (response.ok) {
        const data = await response.json();
        setFileTree(data.tree);
      }
    } catch (err) {
      console.error("Error fetching file tree:", err);
    }
  };

  const fetchFlatFiles = async () => {
    try {
      const response = await fetch("/api/files/flat");
      if (response.ok) {
        const data = await response.json();
        setFlatFiles(data.files);
      }
    } catch (err) {
      console.error("Error fetching flat files list:", err);
    }
  };

  const fetchFileContent = async (pathStr: string) => {
    setIsLoadingFile(true);
    try {
      const response = await fetch(`/api/file?path=${encodeURIComponent(pathStr)}`);
      if (response.ok) {
        const data = await response.json();
        setSelectedFileContent(data.content);
        setSelectedFilePath(pathStr);
        
        // Find architectural description
        const cleanPath = pathStr.replace(/\\/g, "/");
        const matchingFolder = foldersData.find((f) => cleanPath.startsWith(f.path));
        if (matchingFolder) {
          setSelectedFileDescription(
            `This file is part of the **${matchingFolder.name}** module [Layer: ${matchingFolder.layer.toUpperCase()}]. Purpose: ${matchingFolder.purpose}.`
          );
        } else if (pathStr === "pubspec.yaml") {
          setSelectedFileDescription(
            "The configuration file declaring the project package dependencies, Flutter SDK configurations, assets declaration, and Material 3 custom typography."
          );
        } else {
          setSelectedFileDescription(
            "An essential configuration or initialization file governing the development environment setup."
          );
        }
      }
    } catch (err) {
      console.error("Error fetching file content:", err);
    } finally {
      setIsLoadingFile(false);
    }
  };

  const handleToggleExpand = (path: string) => {
    setExpandedNodes((prev) => ({ ...prev, [path]: !prev[path] }));
  };

  const handleCopyCode = () => {
    navigator.clipboard.writeText(selectedFileContent);
    setCopiedFile(true);
    setTimeout(() => setCopiedFile(false), 2000);
  };

  // On-the-fly client-side ZIP generation of the entire Flutter project
  const handleDownloadZip = async () => {
    setIsDownloading(true);
    try {
      const zip = new JSZip();
      
      // We read our flatFiles structure and package them all recursively
      Object.entries(flatFiles).forEach(([filePath, content]) => {
        zip.file(filePath, content as string);
      });
      
      const blob = await zip.generateAsync({ type: "blob" });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "sum_enterprises_flutter_foundation.zip";
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error("Failed to generate ZIP", error);
    } finally {
      setIsDownloading(false);
    }
  };

  // AI Chat Assistant call
  const handleSendChatMessage = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!chatInput.trim() || isSendingToAI) return;

    const userMessage = chatInput;
    setChatInput("");
    setChatMessages((prev) => [
      ...prev,
      { role: "user", text: userMessage, timestamp: new Date() },
    ]);
    setIsSendingToAI(true);

    try {
      const response = await fetch("/api/assistant", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          prompt: userMessage,
          chatHistory: chatMessages.slice(-8).map((m) => ({
            role: m.role,
            text: m.text,
          })),
        }),
      });

      if (response.ok) {
        const data = await response.json();
        setChatMessages((prev) => [
          ...prev,
          { role: "model", text: data.text, timestamp: new Date() },
        ]);
      } else {
        const errData = await response.json();
        setChatMessages((prev) => [
          ...prev,
          {
            role: "model",
            text: `⚠️ **Architect Service Alert**: ${errData.error || "The AI system failed to compile a response. Please check that process.env.GEMINI_API_KEY is configured."}`,
            timestamp: new Date(),
          },
        ]);
      }
    } catch (err) {
      setChatMessages((prev) => [
        ...prev,
        {
          role: "model",
          text: "⚠️ **Network Alert**: Failed to reach the Co-Architect service. Check that your local dev server is active.",
          timestamp: new Date(),
        },
      ]);
    } finally {
      setIsSendingToAI(false);
    }
  };

  // Helper to render the directory node recursively
  const renderFileNode = (node: FileNode, depth = 0) => {
    const isExpanded = expandedNodes[node.path];
    const hasChildren = node.children && node.children.length > 0;
    const isSelected = selectedFilePath === node.path;
    
    // Check if the node matches the architectural filters
    if (fileFilter !== "all" && node.type === "file") {
      const cleanPath = node.path.replace(/\\/g, "/");
      const folderMeta = foldersData.find((f) => cleanPath.startsWith(f.path));
      if (!folderMeta || folderMeta.layer !== fileFilter) {
        return null; // Skip rendering
      }
    }

    return (
      <div key={node.path} className="select-none">
        <div
          onClick={() => {
            if (node.type === "directory") {
              handleToggleExpand(node.path);
            } else {
              fetchFileContent(node.path);
            }
          }}
          style={{ paddingLeft: `${depth * 12 + 6}px` }}
          className={`flex items-center gap-2 py-1.5 px-3 rounded-lg cursor-pointer transition-colors ${
            isSelected
              ? "bg-[#8B4513]/10 text-[#8B4513] font-medium"
              : "hover:bg-slate-100 text-slate-700"
          }`}
        >
          {node.type === "directory" ? (
            <span className="text-slate-400">
              {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
            </span>
          ) : (
            <span className="w-4" />
          )}

          {node.type === "directory" ? (
            <Folder className={`h-4.5 w-4.5 shrink-0 ${isExpanded ? "text-amber-600 fill-amber-100" : "text-amber-500"}`} />
          ) : (
            <File className={`h-4 w-4 shrink-0 ${isSelected ? "text-[#8B4513]" : "text-slate-400"}`} />
          )}

          <span className="text-sm truncate">{node.name}</span>
        </div>

        {node.type === "directory" && isExpanded && node.children && (
          <div className="mt-0.5">
            {node.children.map((child) => renderFileNode(child, depth + 1))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div id="workspace-root" className="min-h-screen bg-[#FAFAFA] font-sans flex flex-col antialiased text-slate-900">
      {/* ------------------------------------------------------------------
          HEADER (Material 3 Google Corporate Style)
         ------------------------------------------------------------------ */}
      <header id="header-bar" className="bg-white border-b border-slate-200/80 sticky top-0 z-40 px-6 py-4 flex items-center justify-between shadow-sm">
        <div className="flex items-center gap-3">
          <div className="bg-[#8B4513] text-white p-2.5 rounded-[12px] flex items-center justify-center shadow-md shadow-[#8B4513]/10">
            <Building className="h-5 w-5" />
          </div>
          <div>
            <h1 className="font-display font-bold text-lg tracking-tight text-slate-900 flex items-center gap-2">
              SUM ENTERPRISES
              <span className="text-[10px] bg-[#8B4513]/10 text-[#8B4513] uppercase font-mono tracking-widest px-2 py-0.5 rounded-full font-bold border border-[#8B4513]/20">
                Flutter Core
              </span>
            </h1>
            <p className="text-xs text-slate-500 font-medium">Private Employee Management Android Foundation • Max 7 Users</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {/* Action Button: Download Entire Zip */}
          <button
            onClick={handleDownloadZip}
            disabled={isDownloading}
            className="flex items-center gap-2 bg-[#8B4513] hover:bg-[#A05A2C] active:bg-[#70350d] text-white px-4 py-2 text-sm font-semibold rounded-[14px] transition-all cursor-pointer shadow-sm disabled:opacity-50"
          >
            {isDownloading ? (
              <>
                <RefreshCw className="h-4 w-4 animate-spin" />
                Packaging ZIP...
              </>
            ) : (
              <>
                <Download className="h-4 w-4" />
                Download Foundation ZIP
              </>
            )}
          </button>
        </div>
      </header>

      {/* ------------------------------------------------------------------
          MAIN WORKSPACE CONTAINER
         ------------------------------------------------------------------ */}
      <main className="flex-1 max-w-[1700px] w-full mx-auto grid grid-cols-1 lg:grid-cols-12 gap-6 p-6">
        
        {/* ------------------------------------------------------------------
            LEFT PANEL: FILE EXPLORER & LAYER FILTER
           ------------------------------------------------------------------ */}
        <section id="left-sidebar" className="lg:col-span-3 bg-white border border-slate-200/80 rounded-[14px] shadow-xs flex flex-col h-[calc(100vh-140px)] overflow-hidden">
          <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
            <div className="flex gap-2">
              <button
                onClick={() => setActiveTab("explorer")}
                className={`text-xs font-bold px-3 py-1.5 rounded-full transition-all flex items-center gap-1 ${
                  activeTab === "explorer"
                    ? "bg-[#8B4513] text-white shadow-xs"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                <Folder className="h-3 w-3" />
                Directories
              </button>
              <button
                onClick={() => setActiveTab("visualizer")}
                className={`text-xs font-bold px-3 py-1.5 rounded-full transition-all flex items-center gap-1 ${
                  activeTab === "visualizer"
                    ? "bg-[#8B4513] text-white shadow-xs"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                <Layers className="h-3 w-3" />
                Layers
              </button>
            </div>
            <span className="text-[10px] font-mono font-bold text-slate-400 bg-slate-100 px-2 py-0.5 rounded-sm">
              Clean Arch
            </span>
          </div>

          {activeTab === "explorer" ? (
            <div className="flex-1 flex flex-col min-h-0">
              {/* Architecture Layer filter pills */}
              <div className="p-3 border-b border-slate-100 flex flex-wrap gap-1.5">
                <span className="text-[10px] font-bold text-slate-400 uppercase w-full mb-1">
                  Filter by Clean Arch Layer:
                </span>
                {(["all", "presentation", "domain", "data", "core"] as const).map((layer) => (
                  <button
                    key={layer}
                    onClick={() => setFileFilter(layer)}
                    className={`text-[10px] font-bold uppercase tracking-wider px-2 py-1 rounded-md transition-all ${
                      fileFilter === layer
                        ? "bg-slate-800 text-white"
                        : "bg-slate-100 text-slate-500 hover:bg-slate-200"
                    }`}
                  >
                    {layer}
                  </button>
                ))}
              </div>

              {/* Recursive File Tree */}
              <div className="flex-1 overflow-y-auto p-3 space-y-0.5">
                {fileTree.length > 0 ? (
                  fileTree.map((node) => renderFileNode(node))
                ) : (
                  <div className="flex flex-col items-center justify-center h-48 text-slate-400">
                    <RefreshCw className="h-6 w-6 animate-spin mb-2" />
                    <span className="text-xs">Assembling directory tree...</span>
                  </div>
                )}
              </div>
            </div>
          ) : (
            /* Interactive Clean Architecture Diagram & Filter Selector */
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              <h3 className="font-display font-bold text-sm text-slate-900">
                Decoupled Data Flow Visualizer
              </h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                SUM Enterprises uses a dependency-injection based Clean Architecture. Click any circle to isolate its specific files:
              </p>

              <div className="flex flex-col gap-3 py-2 items-center">
                {/* 1. Presentation Circle */}
                <button
                  onClick={() => {
                    setFileFilter("presentation");
                    setActiveTab("explorer");
                  }}
                  className="w-full bg-[#8B4513]/5 hover:bg-[#8B4513]/10 border border-[#8B4513]/20 p-3 rounded-xl text-left group transition-all"
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-bold text-[#8B4513] uppercase tracking-wider flex items-center gap-1.5">
                      <Palette className="h-3.5 w-3.5" />
                      1. Presentation Layer
                    </span>
                    <ArrowRight className="h-3 w-3 text-slate-400 group-hover:translate-x-1 transition-transform" />
                  </div>
                  <p className="text-[11px] text-slate-500 leading-tight">
                    Flutter Widgets & Riverpod Notifiers. Exposes corporate states and tracks employee forms securely.
                  </p>
                </button>

                {/* Arrow Down */}
                <div className="h-4 w-0.5 bg-slate-300" />

                {/* 2. Domain Circle */}
                <button
                  onClick={() => {
                    setFileFilter("domain");
                    setActiveTab("explorer");
                  }}
                  className="w-full bg-teal-50 hover:bg-teal-100/70 border border-teal-200/60 p-3 rounded-xl text-left group transition-all"
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-bold text-teal-800 uppercase tracking-wider flex items-center gap-1.5">
                      <Cpu className="h-3.5 w-3.5" />
                      2. Domain Layer (Core Rules)
                    </span>
                    <ArrowRight className="h-3 w-3 text-slate-400 group-hover:translate-x-1 transition-transform" />
                  </div>
                  <p className="text-[11px] text-slate-500 leading-tight">
                    Pure, decoupled entities (UserModel) & Repository Contracts. Completely independent of Firebase SDKs.
                  </p>
                </button>

                {/* Arrow Up */}
                <div className="h-4 w-0.5 bg-slate-300" />

                {/* 3. Data Circle */}
                <button
                  onClick={() => {
                    setFileFilter("data");
                    setActiveTab("explorer");
                  }}
                  className="w-full bg-indigo-50 hover:bg-indigo-100/70 border border-indigo-200/60 p-3 rounded-xl text-left group transition-all"
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-bold text-indigo-800 uppercase tracking-wider flex items-center gap-1.5">
                      <Terminal className="h-3.5 w-3.5" />
                      3. Data Layer
                    </span>
                    <ArrowRight className="h-3 w-3 text-slate-400 group-hover:translate-x-1 transition-transform" />
                  </div>
                  <p className="text-[11px] text-slate-500 leading-tight">
                    Repository implementations & raw data sources (FirebaseAuth, Cloud Firestore, Google Maps API context).
                  </p>
                </button>
              </div>

              <div className="border-t border-slate-100 pt-3">
                <span className="text-xs font-bold text-slate-700 block mb-1">The Golden Rule:</span>
                <p className="text-[11px] text-slate-500 leading-relaxed italic">
                  "Outer layers can refer to inner layers, but inner layers (Domain) MUST NEVER depend on or import outer layers (Data / Presentation)."
                </p>
              </div>
            </div>
          )}
        </section>

        {/* ------------------------------------------------------------------
            CENTER PANEL: CODE VIEWER & SPECIFICATIONS
           ------------------------------------------------------------------ */}
        <section id="code-viewer-panel" className="lg:col-span-5 bg-white border border-slate-200/80 rounded-[14px] shadow-xs flex flex-col h-[calc(100vh-140px)] overflow-hidden">
          {/* Active file metadata header */}
          <div className="p-4 border-b border-slate-100 bg-slate-50/50 flex items-center justify-between shrink-0">
            <div className="flex items-center gap-2.5 overflow-hidden">
              <FileCode className="h-4.5 w-4.5 text-[#8B4513] shrink-0" />
              <div className="overflow-hidden">
                <span className="text-xs text-slate-400 block uppercase tracking-wider font-bold">Active Architecture File</span>
                <span className="text-xs font-mono font-bold text-slate-700 truncate block">sum_enterprises/{selectedFilePath}</span>
              </div>
            </div>

            <button
              onClick={handleCopyCode}
              className="flex items-center gap-1.5 text-xs text-slate-500 hover:text-[#8B4513] hover:bg-slate-100 px-2.5 py-1.5 rounded-lg transition-colors cursor-pointer shrink-0"
            >
              {copiedFile ? (
                <>
                  <Check className="h-3.5 w-3.5 text-green-600" />
                  <span className="text-green-600 font-bold">Copied!</span>
                </>
              ) : (
                <>
                  <Copy className="h-3.5 w-3.5" />
                  <span>Copy Code</span>
                </>
              )}
            </button>
          </div>

          {/* Active File Architectural Context Description */}
          <div className="bg-slate-50 p-3 px-4 border-b border-slate-100 text-xs text-slate-600 flex items-start gap-2.5 shrink-0">
            <Info className="h-4.5 w-4.5 text-[#8B4513] shrink-0 mt-0.5" />
            <div dangerouslySetInnerHTML={{ __html: selectedFileDescription.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>') }} />
          </div>

          {/* Code display block */}
          <div className="flex-1 bg-slate-900 overflow-y-auto font-mono text-xs relative text-slate-300">
            {isLoadingFile ? (
              <div className="absolute inset-0 bg-slate-900/90 flex flex-col items-center justify-center text-slate-400">
                <RefreshCw className="h-8 w-8 animate-spin mb-2" />
                <span>Reading from corporate repository...</span>
              </div>
            ) : (
              <div className="flex min-h-full">
                {/* Simulated line numbers */}
                <div className="w-12 bg-slate-950/40 text-slate-600 text-right pr-3 select-none py-4 border-r border-slate-800">
                  {selectedFileContent.split("\n").map((_, i) => (
                    <div key={i} className="h-5 leading-5">{i + 1}</div>
                  ))}
                </div>
                {/* Code strings */}
                <pre className="flex-1 p-4 overflow-x-auto text-emerald-400 selection:bg-emerald-500/25 h-full">
                  <code className="block leading-5 font-mono text-[11.5px] text-slate-200">
                    {selectedFileContent}
                  </code>
                </pre>
              </div>
            )}
          </div>
        </section>

        {/* ------------------------------------------------------------------
            RIGHT PANEL: AI CO-ARCHITECT & WORKSPACE PREVIEWS
           ------------------------------------------------------------------ */}
        <section id="right-workspace-panel" className="lg:col-span-4 bg-white border border-slate-200/80 rounded-[14px] shadow-xs flex flex-col h-[calc(100vh-140px)] overflow-hidden">
          
          {/* Tab switching row */}
          <div className="grid grid-cols-3 border-b border-slate-100 bg-slate-50/50 p-1 shrink-0">
            <button
              onClick={() => setRightPanelTab("assistant")}
              className={`py-2 text-xs font-bold rounded-lg transition-all flex flex-col items-center gap-1 ${
                rightPanelTab === "assistant"
                  ? "bg-white text-[#8B4513] shadow-xs border border-slate-200/50"
                  : "text-slate-600 hover:text-[#8B4513] hover:bg-white/40"
              }`}
            >
              <Sparkles className="h-4 w-4" />
              AI Architect
            </button>
            <button
              onClick={() => setRightPanelTab("branding")}
              className={`py-2 text-xs font-bold rounded-lg transition-all flex flex-col items-center gap-1 ${
                rightPanelTab === "branding"
                  ? "bg-white text-[#8B4513] shadow-xs border border-slate-200/50"
                  : "text-slate-600 hover:text-[#8B4513] hover:bg-white/40"
              }`}
            >
              <Palette className="h-4 w-4" />
              M3 Preview
            </button>
            <button
              onClick={() => setRightPanelTab("principles")}
              className={`py-2 text-xs font-bold rounded-lg transition-all flex flex-col items-center gap-1 ${
                rightPanelTab === "principles"
                  ? "bg-white text-[#8B4513] shadow-xs border border-slate-200/50"
                  : "text-slate-600 hover:text-[#8B4513] hover:bg-white/40"
              }`}
            >
              <BookOpen className="h-4 w-4" />
              Blueprints
            </button>
          </div>

          {/* Tab Contents */}
          <div className="flex-1 min-h-0 flex flex-col">
            
            {/* TAB 1: AI CO-ARCHITECT ASSISTANT (CONVERGES EXCELLENT WORKPLACE LOGIC) */}
            {rightPanelTab === "assistant" && (
              <div className="flex-1 flex flex-col min-h-0">
                <div className="p-3 bg-[#8B4513]/5 border-b border-[#8B4513]/10 text-[11px] text-slate-600 leading-tight">
                  🧠 <strong>Twin-Agent Gemini Assistant</strong>: Ask me to write code for future models, screens, or explain Riverpod providers adhering to this base architecture!
                </div>
                
                {/* Messages feed */}
                <div className="flex-1 overflow-y-auto p-4 space-y-4">
                  {chatMessages.map((msg, i) => (
                    <div
                      key={i}
                      className={`flex flex-col ${
                        msg.role === "user" ? "items-end" : "items-start"
                      }`}
                    >
                      <div
                        className={`max-w-[90%] p-3 rounded-2xl text-xs leading-relaxed ${
                          msg.role === "user"
                            ? "bg-[#8B4513] text-white rounded-br-none"
                            : "bg-slate-100 text-slate-800 rounded-bl-none"
                        }`}
                      >
                        {/* Render simple markdown bolding and block code styling */}
                        <div className="whitespace-pre-wrap">
                          {msg.text.split("\n").map((line, lineIdx) => {
                            if (line.startsWith("```")) {
                              return null; // Skip markdown code wrappers inside preview
                            }
                            // Detect header paths or inline markdown code highlights
                            let formattedLine = line;
                            return (
                              <p key={lineIdx} className={`${line.includes("lib/") ? "font-mono font-bold text-[10px] text-indigo-900 bg-indigo-50/50 px-1 py-0.5 rounded-md mt-1" : ""}`}>
                                {formattedLine}
                              </p>
                            );
                          })}
                        </div>
                      </div>
                      <span className="text-[9px] text-slate-400 mt-1 uppercase font-mono px-1">
                        {msg.role === "user" ? "Dev" : "Architect"}
                      </span>
                    </div>
                  ))}
                  {isSendingToAI && (
                    <div className="flex items-center gap-2 text-xs text-slate-500 bg-slate-50 p-2 rounded-lg self-start">
                      <RefreshCw className="h-3.5 w-3.5 animate-spin text-[#8B4513]" />
                      <span>Co-Architect is drafting clean code...</span>
                    </div>
                  )}
                  <div ref={chatEndRef} />
                </div>

                {/* Input prompt bar */}
                <form onSubmit={handleSendChatMessage} className="p-3 border-t border-slate-200/80 flex gap-2 bg-white shrink-0">
                  <input
                    type="text"
                    value={chatInput}
                    onChange={(e) => setChatInput(e.target.value)}
                    placeholder="Ask about extending this codebase..."
                    className="flex-1 text-xs px-3.5 py-2.5 rounded-[12px] border border-slate-200 focus:outline-none focus:border-[#8B4513] bg-slate-50 focus:bg-white transition-all"
                  />
                  <button
                    type="submit"
                    disabled={!chatInput.trim() || isSendingToAI}
                    className="bg-[#8B4513] hover:bg-[#A05A2C] text-white p-2.5 rounded-[12px] flex items-center justify-center transition-all disabled:opacity-40 cursor-pointer shadow-xs"
                  >
                    <Send className="h-4 w-4" />
                  </button>
                </form>
              </div>
            )}

            {/* TAB 2: BRANDING & MATERIAL DESIGN 3 PREVIEW VISUALIZER */}
            {rightPanelTab === "branding" && (
              <div className="flex-1 overflow-y-auto p-4 space-y-5">
                <div className="border-b border-slate-100 pb-3">
                  <h3 className="font-display font-bold text-sm text-slate-900 flex items-center gap-2">
                    <Palette className="h-4 w-4 text-[#8B4513]" />
                    Material Design 3 Branding Preview
                  </h3>
                  <p className="text-xs text-slate-500 leading-relaxed mt-1">
                    Displays how the custom Flutter color schemes and design variables will render natively in the Android corporate container.
                  </p>
                </div>

                {/* Color Swatches */}
                <div className="space-y-2">
                  <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">Branding Color Palettes</span>
                  <div className="grid grid-cols-2 gap-2 text-center text-[10px] font-bold">
                    <div className="bg-[#8B4513] text-white p-3 rounded-[10px] shadow-xs">
                      <span>Primary: Copper Brown</span>
                      <span className="block font-mono text-[9px] mt-0.5 font-normal">#8B4513</span>
                    </div>
                    <div className="bg-[#A05A2C] text-white p-3 rounded-[10px] shadow-xs">
                      <span>Secondary: Warm Brown</span>
                      <span className="block font-mono text-[9px] mt-0.5 font-normal">#A05A2C</span>
                    </div>
                    <div className="bg-[#FAFAFA] text-slate-700 border border-slate-200 p-2.5 rounded-[10px]">
                      <span>Background</span>
                      <span className="block font-mono text-[9px] mt-0.5 font-normal">#FAFAFA</span>
                    </div>
                    <div className="bg-white text-slate-700 border border-slate-150 p-2.5 rounded-[10px] shadow-xs">
                      <span>Cards & Sheets</span>
                      <span className="block font-mono text-[9px] mt-0.5 font-normal">#FFFFFF</span>
                    </div>
                  </div>
                </div>

                {/* Simulated Flutter Android Widgets (Rendered with the Copper theme rules) */}
                <div className="space-y-3">
                  <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">Mock Flutter Components (Android M3 Mode)</span>
                  
                  {/* Custom Card & Text */}
                  <div className="bg-white border border-slate-200/70 rounded-[14px] p-4 shadow-sm space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="font-display font-bold text-xs text-slate-900">CustomCard Block</span>
                      <span className="font-mono text-[9px] text-[#A05A2C] font-bold">14px Corners</span>
                    </div>
                    <p className="text-[11px] text-slate-500 leading-normal">
                      Styled with the mandated Space Grotesk display typography and subtle corporate box shadows.
                    </p>
                    
                    {/* Input Field Form */}
                    <div className="space-y-1">
                      <span className="text-[10px] font-bold text-[#8B4513] font-mono">InputDecorationTheme</span>
                      <div className="border border-slate-200 rounded-[14px] bg-white p-2.5 text-xs text-slate-400 flex items-center justify-between">
                        <span>Enter Employee Credentials...</span>
                        <Users className="h-3.5 w-3.5 text-slate-400" />
                      </div>
                    </div>

                    {/* Brand Buttons */}
                    <div className="space-y-2 pt-1">
                      <button className="w-full bg-[#8B4513] hover:bg-[#A05A2C] text-white py-2.5 text-xs font-bold rounded-[14px] transition-all flex items-center justify-center gap-1.5 shadow-sm">
                        <span>CustomButton (Active)</span>
                      </button>
                      <button className="w-full bg-slate-100 text-slate-400 py-2.5 text-xs font-bold rounded-[14px] cursor-not-allowed flex items-center justify-center gap-1.5">
                        <RefreshCw className="h-3 w-3 animate-spin" />
                        <span>Submitting Geofence...</span>
                      </button>
                    </div>
                  </div>

                  {/* Simulated Android Phone Bottom Bar navigation */}
                  <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                    <div className="bg-slate-50 px-3 py-1.5 border-b border-slate-200/50 flex items-center justify-between text-[10px] font-bold text-slate-400">
                      <span>NavigationBar (M3 Default)</span>
                      <span>Android Bar</span>
                    </div>
                    <div className="grid grid-cols-3 py-2 bg-white text-center">
                      <div className="flex flex-col items-center gap-0.5 text-[#8B4513]">
                        <Users className="h-4.5 w-4.5" />
                        <span className="text-[9px] font-bold">Employees</span>
                      </div>
                      <div className="flex flex-col items-center gap-0.5 text-slate-400 hover:text-slate-600 cursor-pointer">
                        <MapPin className="h-4.5 w-4.5" />
                        <span className="text-[9px] font-bold">Field Jobs</span>
                      </div>
                      <div className="flex flex-col items-center gap-0.5 text-slate-400 hover:text-slate-600 cursor-pointer">
                        <CheckCircle className="h-4.5 w-4.5" />
                        <span className="text-[9px] font-bold">Logs</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* TAB 3: BEST PRACTICES BLUEPRINTS & PACKAGES INFO */}
            {rightPanelTab === "principles" && (
              <div className="flex-1 overflow-y-auto p-4 space-y-5">
                <div className="border-b border-slate-100 pb-3">
                  <h3 className="font-display font-bold text-sm text-slate-900 flex items-center gap-2">
                    <BookOpen className="h-4.5 w-4.5 text-[#8B4513]" />
                    Architecture Blueprints
                  </h3>
                  <p className="text-xs text-slate-500 leading-relaxed mt-1">
                    Thorough breakdown of standard packages, Clean Architecture guidelines, and future roadmap instructions.
                  </p>
                </div>

                {/* pubspec.yaml package breakdown */}
                <div className="space-y-3">
                  <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider block">1. pubspec.yaml Dependency Directory</span>
                  <div className="space-y-2">
                    {packagesData.map((pkg) => (
                      <div key={pkg.name} className="border border-slate-150 rounded-xl p-3 bg-slate-50/50 hover:bg-slate-50 transition-colors">
                        <div className="flex items-center justify-between mb-1">
                          <span className="font-mono font-bold text-xs text-slate-800">{pkg.name}</span>
                          <span className="font-mono text-[10px] text-[#8B4513] font-semibold">{pkg.version}</span>
                        </div>
                        <p className="text-[10px] text-slate-400 font-medium italic mb-1">{pkg.purpose}</p>
                        <p className="text-[11px] text-slate-500 leading-relaxed font-sans">{pkg.whyUsed}</p>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Best Practices checklist */}
                <div className="space-y-3 pt-2">
                  <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider block">2. Coding Best Practices</span>
                  <div className="space-y-2.5">
                    {bestPracticesGuides.map((guide, i) => (
                      <div key={i} className="space-y-1">
                        <h4 className="text-xs font-bold text-slate-800">{guide.title}</h4>
                        <p className="text-[11px] text-slate-500 leading-relaxed">{guide.description}</p>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Future Scalability phases */}
                <div className="space-y-3 pt-2">
                  <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider block">3. Future Scalability Roadmap</span>
                  <div className="space-y-3">
                    {scalabilityPlan.map((phase) => (
                      <div key={phase.phase} className="border-l-2 border-[#8B4513] pl-3 space-y-1.5">
                        <h4 className="text-xs font-bold text-[#8B4513]">{phase.phase}</h4>
                        <p className="text-[11px] text-slate-500 leading-normal">{phase.objective}</p>
                        <div className="space-y-1 pl-1">
                          {phase.steps.map((step, idx) => (
                            <div key={idx} className="flex items-start gap-1.5 text-[10px] text-slate-500">
                              <span className="text-[#8B4513] shrink-0 font-bold">•</span>
                              <span className="leading-tight">{step}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
