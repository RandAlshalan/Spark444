import express from "express";
import fetch from "node-fetch";
import dotenv from "dotenv";
import cors from "cors";

dotenv.config();
const app = express();
app.use(express.json());
app.use(cors());

if (!process.env.OPENAI_API_KEY) {
  console.error("Missing OPENAI_API_KEY");
  process.exit(1);
}

// ✅ POST /chat endpoint
app.post("/chat", async (req, res) => {
  try {
    const userMessage = (req.body.message ?? "").toString().trim();
    const resumeId = req.body.resumeId ?? null;
    const trainingType = req.body.trainingType ?? "General";

    if (!userMessage) {
      return res.status(400).json({ error: "Message is required." });
    }

    // ✅ Base system instruction
    let systemPrompt = `
You are an AI interview coach. Answer questions in a professional and concise way suitable for students practicing interviews.
Do NOT use, request, or refer to any personal data (name, GPA, email, university, etc.), even if provided.
Provide neutral, skill-focused, and improvement-oriented responses.
`.trim();

    // ✅ Adjust behavior based on trainingType
    if (trainingType === "Technical Interview") {
      systemPrompt += `
Focus on technical problem-solving, algorithms, and explaining thought processes clearly.
Include follow-up questions like "How would you optimize this?" or "What data structure would you use?".
      `.trim();
    } else if (trainingType === "Behavioral Questions") {
      systemPrompt += `
Focus on STAR method (Situation, Task, Action, Result). Help the student reflect on experiences and soft skills.
      `.trim();
    } else if (trainingType === "English Practice") {
      systemPrompt += `
Focus on language fluency and clarity. Offer polite corrections and alternative phrasing if needed.
      `.trim();
    } else if (trainingType === "Job Interview") {
      systemPrompt += `
Focus on general job readiness, communication confidence, and showcasing motivation.
      `.trim();
    }

    // ✅ Create OpenAI request
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: `The user is practicing a "${trainingType}" session. Question: ${userMessage}`,
          },
        ],
        max_tokens: 800,
        temperature: 0.7,
      }),
    });

    const data = await response.json();

    if (response.status === 429) {
      return res.status(429).json({
        error: "AI service is currently overloaded. Please try again shortly.",
      });
    }

    if (!response.ok) {
      console.error("OpenAI error:", data);
      return res.status(response.status).json({ error: data });
    }

    const reply =
      data.choices?.[0]?.message?.content?.trim() ?? "No response from AI.";
    res.json({ reply });
  } catch (err) {
    console.error("Server error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ✅ Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`AI server running on port ${PORT}`)
);
