"use client";
import {useState,type FormEvent} from "react";
import {tr} from "@/lib/i18n";
type Message={role:"user"|"assistant";content:string;handoff?:boolean};
export default function CarePlanAgent({planId,locale}:{planId:string;locale:string}){
 const [input,setInput]=useState(""),[messages,setMessages]=useState<Message[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState("");
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();const question=input.trim();if(!question||busy)return;
  setMessages(old=>[...old,{role:"user",content:question}]);setInput("");setBusy(true);setError("");
  try{
   const response=await fetch("/api/agent/follow-up",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({planId,message:question,locale})});
   const data=await response.json() as {answer?:string;handoff?:boolean};
   if(response.status===429){setError(tr(locale,"agentRateLimited"));return;}
   if(!response.ok)throw new Error("agent");
   if(typeof data.answer!=="string")throw new Error("agent");
   const answerText:string=data.answer;
   setMessages(old=>[...old,{role:"assistant",content:answerText,handoff:!!data.handoff}]);
  }catch{setError(tr(locale,"agentError"));}
  finally{setBusy(false);}
 }
 return <section className="agent-panel component-stack">
  <h3>{tr(locale,"askCareAgent")}</h3>
  <p className="muted">{tr(locale,"agentDisclaimer")}</p>
  {messages.length>0&&<div className="agent-messages" aria-live="polite">{messages.map((m,i)=><div key={i} className={"agent-message "+m.role+(m.handoff?" handoff":"")}><p>{m.content}</p></div>)}</div>}
  <form className="message-compose" onSubmit={submit}>
   <input value={input} onChange={e=>setInput(e.target.value)} maxLength={2000} placeholder={tr(locale,"agentPlaceholder")} aria-label={tr(locale,"askCareAgent")} required/>
   <button className="btn soft" type="submit" disabled={busy||!input.trim()}>{busy?tr(locale,"messageSending"):tr(locale,"send")}</button>
  </form>
  {error&&<p role="alert" className="form-error">{error}</p>}
 </section>;
}
