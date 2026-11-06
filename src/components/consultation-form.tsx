"use client";
import {useState,type FormEvent} from "react";
import {createClient} from "@/lib/supabase/client";
import {tr} from "@/lib/i18n";
type RecordData={id:string;summary:string;patient_instructions:string;status:"draft"|"published"};
export default function ConsultationForm({doctorId,appointmentId,patientId,initialRecord,initialPrivateNotes,locale}:{doctorId:string;appointmentId:string;patientId:string;initialRecord:RecordData|null;initialPrivateNotes:string;locale:string}){
 const [record,setRecord]=useState<RecordData|null>(initialRecord),[privateNotes,setPrivateNotes]=useState(initialPrivateNotes),[busy,setBusy]=useState(false),[message,setMessage]=useState(""),[dirty,setDirty]=useState(false);
 async function save(event:FormEvent<HTMLFormElement>){event.preventDefault();const form=new FormData(event.currentTarget);setBusy(true);setMessage("");try{
  const supabase=createClient();const summary=String(form.get("summary")||"").trim(),instructions=String(form.get("instructions")||"").trim();
  if(!summary&&!instructions)throw new Error("empty");
  let saved=record;
  if(!saved){const {data,error}=await supabase.from("consultation_records").insert({appointment_id:appointmentId,doctor_id:doctorId,patient_id:patientId,summary,patient_instructions:instructions,status:"draft"}).select("id,summary,patient_instructions,status").single();if(error)throw error;saved=data;setRecord(data);}
  else if(saved.status==="draft"){const {data,error}=await supabase.from("consultation_records").update({summary,patient_instructions:instructions}).eq("id",saved.id).select("id,summary,patient_instructions,status").single();if(error)throw error;saved=data;setRecord(data);}
  const {error:notesError}=await supabase.from("consultation_private_notes").upsert({consultation_id:saved.id,doctor_id:doctorId,notes:privateNotes,updated_at:new Date().toISOString()},{onConflict:"consultation_id"});if(notesError)throw notesError;
  setRecord(saved);setDirty(false);setMessage(tr(locale,"consultationSaved"));
 }catch{setMessage(tr(locale,"consultationFailed"));}finally{setBusy(false);}}
 async function publish(){if(!record||record.status!=="draft")return;if(dirty){setMessage(tr(locale,"saveBeforePublish"));return;}if(!window.confirm(tr(locale,"publishConsultationConfirm")))return;setBusy(true);setMessage("");try{const supabase=createClient();const {data,error}=await supabase.from("consultation_records").update({status:"published"}).eq("id",record.id).select("id,summary,patient_instructions,status").single();if(error)throw error;setRecord(data);setDirty(false);setMessage(tr(locale,"consultationPublished"));}catch{setMessage(tr(locale,"consultationFailed"));}finally{setBusy(false);}}
 const locked=record?.status==="published";
 return <section className="panel component-stack"><h2>{tr(locale,"consultation")}</h2><form onSubmit={save} onChange={()=>setDirty(true)} className="form-stack">
  <div className="input"><label>{tr(locale,"consultationSummary")}</label><textarea name="summary" rows={4} maxLength={5000} defaultValue={record?.summary||""} disabled={locked} placeholder={tr(locale,"consultationSummary")}/></div>
  <div className="input"><label>{tr(locale,"patientInstructions")}</label><textarea name="instructions" rows={4} maxLength={5000} defaultValue={record?.patient_instructions||""} disabled={locked} placeholder={tr(locale,"patientInstructions")}/></div>
  {!locked&&<><div className="input"><label>{tr(locale,"privateNotes")}</label><textarea rows={3} maxLength={10000} value={privateNotes} onChange={e=>{setPrivateNotes(e.target.value);setDirty(true);}} disabled={locked} placeholder={tr(locale,"privateNotes")}/></div><button className="btn primary" type="submit" disabled={busy}>{tr(locale,"saveConsultation")}</button></>}
 </form>
 {record?.status==="draft"&&<button className="btn soft" type="button" onClick={publish} disabled={busy}>{tr(locale,"publishConsultation")}</button>}
 {locked&&<p className="notice">{tr(locale,"consultationLocked")}</p>}
 {message&&<p className="notice" role="status">{message}</p>}
 </section>;
}