"use client";
import {useState,type FormEvent} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
import {tr} from "@/lib/i18n";
type Doctor={id:string;display_name:string;specialty:string;wilaya:string};
export default function HomeVisitForm({doctors,locale}:{doctors:Doctor[];locale:string}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState(""),router=useRouter();
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();const form=e.currentTarget;setBusy(true);setMessage("");
  try{const supabase=createClient(),{data:{user},error:authError}=await supabase.auth.getUser();if(authError||!user)throw new Error(tr(locale,"reconnect"));
   const f=new FormData(form),when=String(f.get("requested_for")||"");const {error}=await supabase.from("home_visit_requests").insert({patient_id:user.id,doctor_id:String(f.get("doctor_id")),wilaya:String(f.get("wilaya")),commune:String(f.get("commune")),address:String(f.get("address")),requested_for:when?new Date(when).toISOString():null,reason:String(f.get("reason")||"")});
   if(error)throw error;setMessage(tr(locale,"homeVisitSent"));form.reset();router.refresh();
  }catch{setMessage(tr(locale,"homeVisitFailed"));}finally{setBusy(false);}
 }
 const min=new Date(Date.now()+10*60*1000-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16);
 return <section className="panel component-stack"><h2>{tr(locale,"homeVisitTitle")}</h2>{doctors.length===0?<p>{tr(locale,"noVerifiedDoctors")}</p>:<form onSubmit={submit} className="form-stack">
 <div className="input"><label>{tr(locale,"professional")}</label><select name="doctor_id" required defaultValue=""><option value="" disabled>{tr(locale,"chooseProfessional")}</option>{doctors.map(d=><option key={d.id} value={d.id}>{d.display_name} · {d.specialty} · {d.wilaya}</option>)}</select></div>
 <div className="two"><div className="input"><label>{tr(locale,"wilaya")}</label><input name="wilaya" required maxLength={80}/></div><div className="input"><label>{tr(locale,"commune")}</label><input name="commune" required maxLength={80}/></div></div>
 <div className="input"><label>{tr(locale,"exactAddress")}</label><textarea name="address" required maxLength={500} rows={2}/></div>
 <div className="input"><label>{tr(locale,"desiredDate")}</label><input type="datetime-local" name="requested_for" min={min}/></div>
 <div className="input"><label>{tr(locale,"reasonOptional")}</label><textarea name="reason" rows={2} maxLength={1000}/></div>
 <button className="btn primary" type="submit" disabled={busy}>{busy?tr(locale,"transmitting"):tr(locale,"sendRequest")}</button></form>}
 {message&&<div className="notice" role="status">{message}</div>}<small className="muted">{tr(locale,"addressPrivacy")}</small></section>;
}