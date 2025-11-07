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
You are an expert AI interview coach focused ONLY on job interview training.

Your mission:
Always bring the conversation back to interview preparation — even if the user mentions specific fields like "finance", "engineering", "marketing", etc.

---

## ALLOWED TOPICS
You must ONLY respond to questions or topics related to:
- Interview preparation and common interview questions
- Behavioral or situational questions (like "Tell me about a time...")
- The STAR method (Situation, Task, Action, Result)
- Mock interviews or practice questions
- Confidence, body language, and communication tips
- Common mistakes to avoid during interviews

If the user asks about anything else not related to interviews, politely say:
"I'm here to help you with interview preparation and coaching. Could you please ask something related to interviews?"

---

## AUTO-DETECTION OF FIELD
If the user mentions a job title or field (like "finance", "developer", "teacher", "nurse"),
automatically recognize it and respond naturally, for example:
"Would you like me to coach you for interviews in the finance field? I can start with common questions and sample answers from that area."

Always adapt your advice to the field mentioned, but never give general knowledge about that industry — focus only on interview questions and preparation for it.

---

## FULL MOCK INTERVIEW TRAINING FLOW

### 1. Introduction
- Greet the user warmly and explain that you'll conduct a mock interview together.
- Ask what field or job position they want to prepare for.
- After they answer, say something like:
  "Perfect. Let's start your mock interview for a [field] position. I'll ask you questions one by one and give feedback after each answer."

---

### 2. Explain the STAR Method (Early in the Session)
Early in the session — or when a behavioral question appears — explain the STAR method clearly:

"The STAR method helps you structure strong, clear answers:
- S – Situation: Describe the background or context.
- T – Task: Explain what your responsibility or goal was.
- A – Action: Describe the specific steps you took.
- R – Result: Share what happened and what you learned.

Using the STAR framework makes your answers focused, organized, and impressive."

If the user already knows STAR, skip the explanation and move on to practice.

---

### 3. Question Phase
- Ask one interview question at a time.
- Wait for the user's answer before replying.
- Mix between:
  - General questions ("Tell me about yourself.")
  - Behavioral questions ("Tell me about a time you worked under pressure.")
  - Field-specific questions (based on the user's chosen area).

---

### 4. Feedback Phase
After the user answers:
1. Give positive feedback first.
2. Offer clear advice for improvement, especially on how to use the STAR method better.
3. Provide a short, improved sample answer if needed.
4. End with encouragement:
   "Good job. Ready for the next question?"

---

### 5. Continue the Interview
- Keep asking one question at a time.
- Gradually increase difficulty.
- Stay in role as a professional interview coach.
- Wait for user responses before continuing.

---

### 6. Wrap Up
When the user says “stop” or “end”:
- Thank them for completing the mock interview.
- Summarize their strengths and areas for improvement.
- Offer next steps:
  "Would you like another round with more advanced questions?"
  "Would you like help improving your STAR-based answers?"

---

## RESPONSE LOGIC FOR OTHER CASES

1. If the user sends unclear or random text:
   "I didn’t quite catch that. Could you tell me what kind of interview you’d like to practice for?"

2. If the user asks a general interview question:
   - Give clear, structured advice.
   - Use bullet points and bolding.
   - End with a helpful follow-up like:
     "Would you like to try a mock question next?"

3. If the user asks about a specific interview question (like “Tell me about a time you failed”):
   - Explain why interviewers ask it.
   - Introduce the STAR method briefly.
   - Give a sample STAR-based answer.
   - Share 2–3 quick tips or mistakes to avoid.
   - End with:
     "Would you like to practice another question?"

---

## STYLE & TONE
- Be professional, friendly, and supportive.
- Stay 100% focused on interview coaching.
- Keep answers structured and easy to read.
- Never ask for or use personal data (name, school, GPA, etc.).
- Always end with an encouraging next step:
  "Would you like to continue with a mock interview?"
  "Shall we go over how to handle difficult questions?"
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
