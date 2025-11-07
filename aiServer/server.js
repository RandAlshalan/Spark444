
import express from "express";
import fetch from "node-fetch";
import dotenv from "dotenv";
import cors from "cors";

dotenv.config();
const app = express();
app.use(express.json()); // Middleware to parse JSON bodies
app.use(cors()); // Middleware to enable Cross-Origin Resource Sharing

// Check for the essential API key on startup
if (!process.env.OPENAI_API_KEY) {
  console.error("FATAL ERROR: Missing OPENAI_API_KEY");
  process.exit(1);
}

// OpenAI API endpoint
const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

app.post("/chat", async (req, res) => {
  try {
    // --- The most important change: Receive the messages array and other variables ---
    const { messages, resumeId, trainingType } = req.body;

    // Validate that 'messages' is a non-empty array
    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: "Messages array is required." });
    }

    // --- Intelligently build the System Prompt ---
    // This tells the AI how to behave based on the inputs
    let systemPrompt = `
You are an expert AI interview coach focused **only** on personal interviews and interview training.

❗️IMPORTANT RULE:
You must **only** respond to questions or topics related to:
- Interview preparation
- Common interview questions and answers
- Body language, communication skills, and confidence
- STAR method and behavioral questions
- Mock interviews or interview simulations
- Job interview tips or mistakes

If the user asks about **anything else not related to interviews or interview training**, you must politely say:
"I'm here to help you with interview preparation and training. Could you please ask something related to interviews?"

Your tone is supportive, encouraging, and professional. Your goal is to help students feel confident and ready for interviews.

**CRITICAL RULE:** Never ask for or use any personal data (like name, school, GPA, company, etc.). Keep answers general and educational.

When a student asks for help with a specific interview question (e.g., "Tell me about a time you failed"):
1. **Explain the 'Why':**
   - Briefly explain *why* interviewers ask that question.
2. **Give a Framework:**
   - Use the **STAR method** (Situation, Task, Action, Result) and explain each step.
3. **Provide an Example:**
   - Give a solid, general example answer.
4. **Offer Tips:**
   - List 2–3 key tips or pitfalls to avoid.

When a student asks for general advice (e.g., "How to handle nervousness" or "What to wear to an interview"):
- Provide actionable, structured tips.
- Use **bolding** and **bullet points** for clarity.

Always end with a next step, like:
"Would you like to practice another question?" or "Shall we review body language next?"
`.trim();


    if (resumeId) {
      systemPrompt += `\n\n**User Context:** You MUST tailor your answers based on the user's resume (ID: ${resumeId}). Refer to their skills and experience when providing examples.`;
    }
    if (trainingType) {
      systemPrompt += `\n\n**Training Context:** The user is in a specific training program: '${trainingType}'. Focus your advice on this area (e.g., job roles, skills) related to this training.`;
    }

    // Combine the dynamic system prompt with the chat history
// If you store chat history with 'ai' role:
const apiMessages = messages.map(msg => {
  return {
    role: msg.role === 'ai' ? 'assistant' : msg.role,
    content: msg.text || msg.content
  };
});


    const response = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: apiMessages, // Send the full history + system prompt
        max_tokens: 800,
        temperature: 0.7,
      }),
    });

    const data = await response.json();

    // Handle API-specific errors
    if (response.status === 429) {
      return res.status(429).json({
        error: "AI service is currently overloaded. Please try again shortly.",
      });
    }
    if (!response.ok) {
      console.error("OpenAI error:", data);
      return res.status(response.status).json({ error: data.error?.message || "OpenAI API error" });
    }

    const reply = data.choices?.[0]?.message?.content?.trim() ?? "No response from AI.";
    res.json({ reply });
  } catch (err) {
    console.error("Server error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`AI server running on port ${PORT}`));