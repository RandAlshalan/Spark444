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

app.post("/chat", async (req, res) => {
  try {
   
    const userMessage = (req.body.message ?? "").toString().trim();
    if (!userMessage) {
      return res.status(400).json({ error: "Message is required." });
    }

    
    const systemPrompt = `
You are an AI interview coach. Answer interview questions in a professional, general way suitable for students preparing for job interviews.
DO NOT use, request, or reference any personal or profile data about the user (name, university, skills, email, GPA, etc.), even if that data is provided.
Provide concise, actionable, and neutral answers. Offer example responses, tips for improvement, and follow-up questions when appropriate.
    `.trim();

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
          { role: "user", content: userMessage }
        ],
        max_tokens: 800,
        temperature: 0.7,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error("OpenAI error:", data);
      return res.status(response.status).json({ error: data });
    }

    const reply = data.choices?.[0]?.message?.content?.trim() ?? "No response from AI.";
    res.json({ reply });
  } catch (err) {
    console.error("Server error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 AI server running on port ${PORT}`));
