#!/usr/bin/env python3
"""Test 1-800-BAD-CODE punctuation restoration model against real dictation samples."""

from punctuators.models.punc_cap_seg_model import PunctCapSegConfigONNX, PunctCapSegModelONNX
import time

cfg = PunctCapSegConfigONNX(
    hf_repo_id="1-800-BAD-CODE/punctuation_fullstop_truecase_english",
    spe_filename="spe_32k_lc_en.model",
    model_filename="punct_cap_seg_en.onnx",
    config_filename="config.yaml",
)
model = PunctCapSegModelONNX(cfg)
print("Model loaded.\n")

tests = [
    ("Test 1 - Real dictation (sparse punctuation)",
     "Hi Reyno! How is everything? I wanted to talk to you about our project Where we go from here, whats highest priority and when you have time for a meeting Okay, thats all Best regards Sebastian"),

    ("Test 2 - Earlier dictation (well punctuated)",
     "Hello, Reino! So, we have some work to do I guess. There is three things that I want to go through. First things first, there is a new document that we need to take a look at. Second thing, I have some feedback regarding a code review. And the third thing, we need to set a date for when we re going to start working. Okay, so how is life? How are you? How is my mom? Any news about the new car? Okay, have a good day. Best regards, Sebastian."),

    ("Test 3 - Meeting + personal (problem case)",
     "Hi Reino! So we need to have a new meeting where we can discuss the project and how to move forward. Can you have time tomorrow for a meeting at 4 o clock? PM? Hows the family? Is everything okay? Are you preparing for the Easter festivities? Hows your health? Everything good? Okay thats all. Best regards, Sebastian."),

    ("Test 4 - Simulated ZERO punctuation",
     "I wanted to reach out about the project we discussed last week I think we should schedule a call to go over the requirements and make sure we are aligned on the timeline"),

    ("Test 5 - Short casual no punctuation",
     "hey just checking in on that thing we talked about let me know when you have a minute"),

    ("Test 6 - Run-on with conjunctions",
     "I woke up and I had coffee and then I went to the gym and after that I sat down to work and I got through most of my emails"),

    ("Test 7 - Question without question mark",
     "did you get a chance to look at the document I sent over"),

    ("Test 8 - Mixed work and personal no punctuation",
     "so about the meeting tomorrow I think we should move it to Thursday because I have a conflict also how are the kids doing I heard they started a new school"),
]

for name, text in tests:
    t0 = time.time()
    result = model.infer([text])
    ms = (time.time() - t0) * 1000

    print(f"=== {name} ({ms:.0f}ms) ===")
    print(f"IN:  {text}")
    print(f"OUT: {' | '.join(result[0])}")
    print()
