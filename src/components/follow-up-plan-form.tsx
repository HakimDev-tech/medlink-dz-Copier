"use client";
import {useState,type FormEvent} from "react";
import {createClient} from "@/lib/supabase/client";
import {localeTag,tr} from "@/lib/i18n";
type AppointmentOption={id:string;patient_id:string;starts_at:string};
type EventOption={id:string;event_at:string;label:string;instruction:string|null};
export default function FollowUpPlanForm({doctorId,appointments,locale}:{doctorId:string;appointments:AppointmentOption[];locale:string}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState(""),[draftId,setDraftId]=useState<string|null>(null),[events,setEvents]=useState<EventOption[]>([]);
 async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();const el=event.currentTarget;setBusy(true);setMessage("");try{const form=new FormData(el),appointment=appointments.find(a=>a.id===String(form.get("appointment")||""));if(!appointment)throw new Error("appointment");const start=String(form.get("starts_on")||""),end=String(form.get("ends_on")||"");if(end&&end<start)throw new Error("date");const supabase=createClient();const {data,error}=await supabase.from("follow_up_plans").insert({doctor_id:doctorId,patient_id:appointment.patient_id,appointment_id:appointment.id,title:String(form.get("title")||"").trim(),instructions:String(form.get("instructions")||"").trim(),starts_on:start,ends_on:end||null,status:"draft"}).select("id").single();if(error)throw error;setDraftId(data.id);setEvents([]);setMessage(tr(locale,"draftSaved"));}catch(e){setMessage(e instanceof Error&&e.message==="appointment"?tr(locale,"selectAppointment"):e instanceof Error&&e.message==="date"?tr(locale,"endAfterStart"):tr(locale,"saveFailed"));}finally{setBusy(false);}}
 async function addEvent(event:FormEvent<HTMLFormElement>){event.preventDefault();if(!draftId)return;const el=event.currentTarget;const form=new FormData(el),raw=String(form.get("event_at")||""),label=String(form.get("label")||"").trim(),instruction=String(form.get("instruction")||"").trim();const at=new Date(raw);if(!raw||!label||Number.isNaN(at.getTime())||at.getTime()<=Date.now()){setMessage(tr(locale,"chooseFuture"));return;}setBusy(true);setMessage("");try{const supabase=createClient();const {data,error}=await supabase.from("follow_up_events").insert({plan_id:draftId,event_at:at.toISOString(),label,instruction:instruction||null}).select("id,event_at,label,instruction").single();if(error)throw error;setEvents(old=>[...old,data]);el.reset();setMessage(tr(locale,"eventAdded"));}catch{setMessage(tr(locale,"eventFailed"));}finally{setBusy(false);}}
 async function publish(){if(!draftId||events.length===0){setMessage(tr(locale,"noEvents"));return;}setBusy(true);setMessage("");try{const supabase=createClient();const {error}=await supabase.from("follow_up_plans").update({status:"published",approved_at:new Date().toISOString()}).eq("id",draftId);if(error)throw error;setMessage(tr(locale,"followUpPublished"));setDraftId(null);setEvents([]);}catch{setMessage(tr(locale,"publishFailed"));}finally{setBusy(false);}}
 return <section className="panel component-stack"><h2>{tr(locale,"createFollowUp")}</h2>
 {appointments.length===0?<p className="muted">{tr(locale,"noAppointmentsForFollowUp")}</p>:<form onSubmit={submit} className="form-stack">
 <div className="input"><label>{tr(locale,"appointmentPatient")}</label><select name="appointment" required defaultValue=""><option value="" disabled>{tr(locale,"chooseAppointment")}</option>{appointments.map(a=><option key={a.id} value={a.id}>Patient #{a.patient_id.slice(0,8)} · {new Date(a.starts_at).toLocaleString(localeTag(locale))}</option>)}</select></div>
 <div className="input"><label>{tr(locale,"followUpTitle")}</label><input name="title" required maxLength={120}/></div>
 <div className="input"><label>{tr(locale,"approvedInstructions")}</label><textarea name="instructions" required rows={4} maxLength={3000}/></div>
 <div className="two"><div className="input"><label>{tr(locale,"start")}</label><input type="date" name="starts_on" required/></div><div className="input"><label>{tr(locale,"endOptional")}</label><input type="date" name="ends_on"/></div></div>
 <button className="btn primary" type="submit" disabled={busy||!!draftId}>{busy?tr(locale,"sending"):tr(locale,"saveDraft")}</button></form>}
 {draftId&&<div className="component-stack"><h3>{tr(locale,"events")}</h3><form onSubmit={addEvent} className="form-stack">
 <div className="input"><label>{tr(locale,"eventDate")}</label><input type="datetime-local" name="event_at" required/></div>
 <div className="input"><label>{tr(locale,"eventLabel")}</label><input name="label" required maxLength={140}/></div>
 <div className="input"><label>{tr(locale,"eventInstruction")}</label><textarea name="instruction" rows={2} maxLength={1000}/></div>
 <button className="btn soft" type="submit" disabled={busy}>{tr(locale,"addEvent")}</button></form>
 {events.map(e=><div className="row" key={e.id}><div><strong>{e.label}</strong><small>{new Date(e.event_at).toLocaleString(localeTag(locale))}</small>{e.instruction&&<small>{e.instruction}</small>}</div></div>)}
 <button className="btn primary" type="button" onClick={publish} disabled={busy||events.length===0}>{tr(locale,"publishFollowUp")}</button>
 </div>}
 {message&&<div className="notice" role="status">{message}</div>}</section>;
}