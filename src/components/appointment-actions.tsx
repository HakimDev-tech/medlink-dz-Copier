"use client";
import {useState} from "react";import {useRouter} from "next/navigation";import Link from "next/link";import {createClient} from "@/lib/supabase/client";import {tr} from "@/lib/i18n";
export default function AppointmentActions({id,status,locale}:{id:string;status:string;locale:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 async function change(next:"confirmed"|"rejected"|"completed"){setBusy(true);setError("");try{const supabase=createClient(),{error}=await supabase.from("appointments").update({status:next}).eq("id",id);if(error)throw error;router.refresh();}catch{setError(tr(locale,"updateFailed"));}finally{setBusy(false);}}
 const label=(s:string)=>tr(locale,("status_"+s) as Parameters<typeof tr>[1]);
 if(status==="completed")return <div className="action-group"><span className="tag">{label(status)}</span><Link className="btn soft" href={`/${locale}/professional/consultation/${id}`}>{tr(locale,"openConsultation")}</Link></div>;
 if(status==="cancelled"||status==="rejected")return <span className="tag">{label(status)}</span>;
 return <div className="action-group">{status==="requested"&&<><button className="btn soft" type="button" disabled={busy} onClick={()=>change("confirmed")}>{tr(locale,"confirm")}</button><button className="btn quiet" type="button" disabled={busy} onClick={()=>change("rejected")}>{tr(locale,"reject")}</button></>}{status==="confirmed"&&<button className="btn soft" type="button" disabled={busy} onClick={()=>change("completed")}>{tr(locale,"complete")}</button>}{error&&<small role="alert" className="form-error">{error}</small>}</div>;
}