"use client";
import {useState,type FormEvent} from "react";
import {createClient} from "@/lib/supabase/client";
import {localeTag,tr} from "@/lib/i18n";
type AppointmentOption={id:string;patient_id:string;starts_at:string};
export default function FollowUpPlanForm({doctorId,appointments,locale}:{doctorId:string;appointments:AppointmentOption[];locale:string}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState(""),[draftId,setDraftId]=useState<string|null>(null);
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();const formElement=event.currentTarget;setBusy(true);setMessage("");
  try{const form=new FormData(formElement),appointment=appointments.find(a=>a.id===String(form.get("appointment")||""));if(!appointment)throw new Error(tr(locale,"selectAppointment"));
   const start=String(form.get("starts_on")||""),end=String(form.get("ends_on")||"");if(end&&end<start)throw new Error(tr(locale,"endAfterStart"));
   const supabase=createClient();const {data,error}=await supabase.from("follow_up_plans").insert({doctor_id:doctorId,patient_id:appointment.patient_id,appointment_id:appointment.id,title:String(form.get("title")||""),instructions:String(form.get("instructions")||""),starts_on:start,ends_on:end||null,status:"draft"}).select("id").single();
   if(error)throw error;setDraftId(data.id);setMessage(tr(locale,"draftSaved"));formElement.reset();
  }catch(e){setMessage(e instanceof Error&&(e.message===tr(locale,"selectAppointment")||e.message===tr(locale,"endAfterStart"))?e.message:tr(locale,"saveFailed"));}
  finally{setBusy(false);}
 }
 async function publish(){if(!draftId)return;setBusy(true);setMessage("");try{const supabase=createClient();const {error}=await supabase.from("follow_up_plans").update({status:"published",approved_at:new Date().toISOString()}).eq("id",draftId);if(error)throw error;setMessage(tr(locale,"followUpPublished"));setDraftId(null);}catch{setMessage(tr(locale,"publishFailed"));}finally{setBusy(false);}}
 return <section className="panel component-stack"><h2>{tr(locale,"createFollowUp")}</h2>
 {appointments.length===0?<p className="muted">{tr(locale,"noAppointmentsForFollowUp")}</p>:<form onSubmit={submit} className="form-stack">
 <div className="input"><label>{tr(locale,"appointmentPatient")}</label><select name="appointment" required defaultValue=""><option value="" disabled>{tr(locale,"chooseAppointment")}</option>{appointments.map(a=><option key={a.id} value={a.id}>Patient #{a.patient_id.slice(0,8)} · {new Date(a.starts_at).toLocaleString(localeTag(locale))}</option>)}</select></div>
 <div className="input"><label>{tr(locale,"followUpTitle")}</label><input name="title" required maxLength={120}/></div>
 <div className="input"><label>{tr(locale,"approvedInstructions")}</label><textarea name="instructions" required rows={4} maxLength={3000}/></div>
 <div className="two"><div className="input"><label>{tr(locale,"start")}</label><input type="date" name="starts_on" required/></div><div className="input"><label>{tr(locale,"endOptional")}</label><input type="date" name="ends_on"/></div></div>
 <button className="btn primary" type="submit" disabled={busy}>{busy?tr(locale,"sending"):tr(locale,"saveDraft")}</button></form>}
 {draftId&&<button className="btn soft" type="button" onClick={publish} disabled={busy}>{tr(locale,"publishFollowUp")}</button>}
 {message&&<div className="notice" role="status">{message}</div>}</section>;
}