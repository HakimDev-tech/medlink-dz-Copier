"use client";
import {useState,type FormEvent} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
import {tr} from "@/lib/i18n";
export default function DoctorBooking({doctorId,locale}:{doctorId:string;locale:string}){
 const [open,setOpen]=useState(false),[busy,setBusy]=useState(false),[message,setMessage]=useState(""),router=useRouter();
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();setBusy(true);setMessage("");
  try{const supabase=createClient();const {data,error}=await supabase.auth.getUser();if(error)throw error;if(!data.user){router.push("/"+locale+"/login");return;}
   const form=new FormData(event.currentTarget),raw=String(form.get("starts_at")||""),startsAt=new Date(raw);
   if(!raw||Number.isNaN(startsAt.getTime())||startsAt.getTime()<=Date.now())throw new Error(tr(locale,"chooseFuture"));
   const {error:writeError}=await supabase.from("appointments").insert({patient_id:data.user.id,doctor_id:doctorId,starts_at:startsAt.toISOString(),status:"requested"});
   if(writeError)throw writeError;setMessage(tr(locale,"requestSent"));setOpen(false);
  }catch(e){setMessage(e instanceof Error&&e.message===tr(locale,"chooseFuture")?e.message:tr(locale,"requestFailed"));}
  finally{setBusy(false);}
 }
 const min=new Date(Date.now()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16);
 return <div className="component-stack"><button className="btn primary" type="button" aria-expanded={open} onClick={()=>setOpen(v=>!v)}>{open?tr(locale,"close"):tr(locale,"requestAppointment")}</button>
 {open&&<form onSubmit={submit} className="form-stack"><div className="input"><label>{tr(locale,"desiredDate")}</label><input name="starts_at" type="datetime-local" min={min} required/></div><button className="btn primary" disabled={busy} type="submit">{busy?tr(locale,"sending"):tr(locale,"sendRequest")}</button></form>}
 {message&&<div className="notice" role="status">{message}</div>}</div>;
}