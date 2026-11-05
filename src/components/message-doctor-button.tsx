"use client";
import {useState} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
export default function MessageDoctorButton({doctorId,locale}:{doctorId:string;locale:string}){
 const [busy,setBusy]=useState(false),[error,setError]=useState("");const router=useRouter();
 async function open(){
  setBusy(true);setError("");
  try{const supabase=createClient();const {data:{user},error:authError}=await supabase.auth.getUser();if(authError)throw authError;if(!user){router.push("/"+locale+"/login");return;}
   let {data:conversation,error:readError}=await supabase.from("conversations").select("id").eq("patient_id",user.id).eq("doctor_id",doctorId).maybeSingle();
   if(readError)throw readError;
   if(!conversation){const {data,error:insertError}=await supabase.from("conversations").insert({patient_id:user.id,doctor_id:doctorId}).select("id").single();if(insertError)throw insertError;conversation=data;}
   router.push("/"+locale+"/patient/messages");
  }catch(e){setError(e instanceof Error?e.message:"Impossible d'ouvrir la conversation.");}
  finally{setBusy(false);}
 }
 return <div style={{marginTop:8}}><button type="button" className="btn soft" onClick={open} disabled={busy}>{busy?"Ouverture…":"Contacter ce professionnel"}</button>{error&&<small role="alert" style={{display:"block",color:"#a33"}}>{error}</small>}</div>;
}