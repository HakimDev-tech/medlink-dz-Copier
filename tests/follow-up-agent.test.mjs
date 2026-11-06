import test from "node:test";
import assert from "node:assert/strict";
import {answerFromCarePlan} from "../src/lib/agent/follow-up-agent.ts";

const context={
  title:"Suivi après consultation",
  instructions:"Prenez rendez-vous de contrôle avec votre médecin. Notez les questions à lui poser avant le prochain rendez-vous.",
  starts_on:"2026-11-07",
  ends_on:"2026-11-21",
  events:[
    {event_at:"2026-11-08T09:00:00.000Z",label:"Rendez-vous de contrôle",instruction:"Présentez-vous à l'heure convenue."}
  ]
};

test("answers only from matching published-plan passages",()=>{
  const result=answerFromCarePlan("Comment préparer mon prochain rendez-vous ?",context,"fr");
  assert.equal(result.outcome,"answered_from_plan");
  assert.match(result.answer,/Notez les questions|rendez-vous de contrôle/i);
  assert.equal(result.handoff,false);
});

test("returns plan period from stored metadata",()=>{
  const result=answerFromCarePlan("When does my plan start?",context,"en");
  assert.equal(result.intent,"plan_lookup");
  assert.match(result.answer,/Plan: Suivi après consultation/);
  assert.match(result.answer,/Start:/);
  assert.match(result.answer,/End:/);
});

test("hands medication and dosage questions to the professional",()=>{
  const result=answerFromCarePlan("Can I change my medication dose?",context,"en");
  assert.equal(result.outcome,"human_handoff");
  assert.equal(result.intent,"out_of_scope");
  assert.equal(result.handoff,true);
});

test("flags potential emergencies without attempting assessment",()=>{
  const result=answerFromCarePlan("I have chest pain and difficulty breathing",context,"en");
  assert.equal(result.intent,"urgent_escalation");
  assert.equal(result.outcome,"human_handoff");
  assert.ok(result.safetyFlags.includes("possible_urgent_symptom"));
});

test("returns stored reminders using the Algeria time zone",()=>{
  const result=answerFromCarePlan("When is my next reminder?",context,"fr");
  assert.equal(result.intent,"schedule_lookup");
  assert.match(result.answer,/Rendez-vous de contrôle/);
  assert.match(result.answer,/Présentez-vous/);
});

test("does not invent information missing from the approved plan",()=>{
  const result=answerFromCarePlan("Can I go swimming tomorrow?",context,"en");
  assert.equal(result.outcome,"human_handoff");
  assert.match(result.answer,/cannot find this information/i);
});
