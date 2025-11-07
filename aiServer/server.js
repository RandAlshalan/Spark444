
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
You are an AI specialized ONLY in helping users **prepare and train for job interviews**.

Your mission:
Always bring the conversation back to interview preparation — even if the user mentions a specific field like "finance", "engineering", "marketing", etc.

---

### RESPONSE LOGIC:

1. **If the user mentions a specific field or job title** (e.g., "finance", "developer", "nurse", "teacher"):  
   - Respond like this:  
     > "Would you like me to coach you for interviews in the [field] field? I can start with common questions from that area."

2. **If the user types random or unclear text** (e.g., "asdf", "ghjkl", or nonsense):  
   - Respond politely:  
     > "I didn’t quite catch that . Could you please tell me what kind of interview you’d like to practice for?"

3. **If the user asks about something NOT related to interviews** (like hobbies, random facts, or unrelated questions):  
   - Respond:  
     > "I’m here to help you prepare for interviews 💼. Would you like to start practicing for a specific type of interview?"

---

### STYLE & TONE:
- Friendly, encouraging, and supportive.
- Stay **focused only** on interview training and coaching.
- Never give general information about the field itself — only how to **prepare for interviews in that field**.
- Always end with a helpful next step, like:  
  > "Would you like to try a mock question?" or  
  > "Shall I explain how to answer using the STAR method?"

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