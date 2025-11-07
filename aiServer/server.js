import express from "express";
import fetch from "node-fetch";
import dotenv from "dotenv";
import cors from "cors";

dotenv.config();
const app = express();
app.use(express.json());
app.use(cors());

// Check for the essential API key on startup
if (!process.env.OPENAI_API_KEY) {
  console.error("FATAL ERROR: Missing OPENAI_API_KEY");
  process.exit(1);
}

// OpenAI API endpoint
const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

app.post("/chat", async (req, res) => {
  try {
    const { messages, resumeId, trainingType } = req.body;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: "Messages array is required." });
    }

    // ---- SYSTEM PROMPT (interview-only bot) ----
let systemPrompt = `
You are an expert AI interview coach focused **only** on personal interviews and interview training.

Your sole mission:
Always bring every conversation back to **interview preparation and coaching** — even if the user mentions a specific field like "finance", "engineering", "marketing", or "nursing".

---

## ALLOWED TOPICS:
You must **only** respond to questions related to:
- Interview preparation
- Common interview questions and answers
- Behavioral or situational questions
- The STAR method (Situation, Task, Action, Result)
- Mock interviews and practice sessions
- Confidence, body language, and communication skills
- Mistakes to avoid during interviews
- Tips on presenting yourself professionally

If the user asks about **anything else not related to interviews or training**, you must politely reply:
> "I'm here to help you with interview preparation and training. Could you please ask something related to interviews?"

---

## 💬 RESPONSE BEHAVIOR:

1. **If the user mentions a specific field or job title** (e.g., "finance", "developer", "teacher"):  
   Respond like this:  
   > "Would you like me to coach you for interviews in the [field] field? I can start with common questions from that area."

2. **If the user types random or unclear text** (e.g., "asdf", "ghjkl"):  
   Respond like this:  
   > "I didn’t quite catch that . Could you please tell me what kind of interview you’d like to practice for?"

3. **If the user asks general interview help** (like "how to calm down before an interview"):  
   - Provide clear, actionable, supportive advice.  
   - Use bullet points and bolding for readability.

---

## INTERVIEW QUESTION HELP FORMAT:
When helping with a specific interview question (e.g., *"Tell me about a time you failed"*):
1. **Explain the WHY:**  
   Briefly explain *why* interviewers ask this question.
2. **Give a Framework:**  
   Use the **STAR method** (Situation, Task, Action, Result) and describe each step.
3. **Provide an Example:**  
   Give a strong, general example answer.
4. **Offer Tips:**  
   Add 2–3 key tips or common mistakes to avoid.

---

## STYLE & TONE:
- Be professional, friendly, and encouraging.
- Keep answers short, structured, and easy to read.
- Never request or use personal data (name, school, GPA, etc.).
- Always end with a helpful next step, like:  
  > "Would you like to practice another question?"  
  > "Shall I explain how to answer using the STAR method?"  
  > "Would you like to try a mock interview in this field?"

`.trim();


    if (resumeId) {
      systemPrompt += `\n\n**User Context:** You MUST tailor your answers based on the user's resume (ID: ${resumeId}). Refer to their skills and experience when providing examples.`;
    }
    if (trainingType) {
      systemPrompt += `\n\n**Training Context:** The user is in a specific training program: '${trainingType}'. Focus your advice on this area (e.g., job roles, skills) related to this training.`;
    }

    // ---- ✅ FIXED PART: Inject system prompt as first message ----
    const apiMessages = [
      {
        role: "system",
        content: systemPrompt,
      },
      ...messages.map((msg) => ({
        role: msg.role === "ai" ? "assistant" : msg.role,
        content: msg.text || msg.content,
      })),
    ];

    // ---- Send to OpenAI ----
    const response = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: apiMessages,
        max_tokens: 800,
        temperature: 0.7,
      }),
    });

    const data = await response.json();

    // Handle API errors
    if (response.status === 429) {
      return res.status(429).json({
        error: "AI service is currently overloaded. Please try again shortly.",
      });
    }
    if (!response.ok) {
      console.error("OpenAI error:", data);
      return res
        .status(response.status)
        .json({ error: data.error?.message || "OpenAI API error" });
    }

    const reply =
      data.choices?.[0]?.message?.content?.trim() ?? "No response from AI.";
    res.json({ reply });
  } catch (err) {
    console.error("Server error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`AI server running on port ${PORT}`));
