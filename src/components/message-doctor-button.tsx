"use client";
import {useState} from "react";import {useRouter} from "next/navigation";import {createClient} from "@/lib/supabase/client";import {tr} from "@/lib/i18n";
export default function MessageDoctorButton({doctorId,locale}:{doctorId:string;locale:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 async function open(){setBusy(true);setError("");try{const supabase=createClient(),{data:{user},error:authError}=await supabase.auth.getUser();if(authError||!user){router.push("/"+locale+"/login");return;}
  const {data:existingConversation,error:readError}=await supabase.from("conversations").select("id").eq("patient_id",user.id).eq("doctor_id",doctorId).maybeSingle();if(readError)throw readError;let conversation=existingConversation;
  if(!conversation){const {data,error}=await supabase.from("conversations").insert({patient_id:user.id,doctor_id:doctorId}).select("id").single();if(error)throw error;conversation=data;}
  router.push("/"+locale+"/patient/messages");
 }catch{setError(tr(locale,"conversationFailed"));}finally{setBusy(false);}}
 return <div className="component-stack"><button type="button" className="btn soft" onClick={open} disabled={busy}>{busy?tr(locale,"opening"):tr(locale,"openConversation")}</button>{error&&<small role="alert" className="form-error">{error}</small>}</div>;
}