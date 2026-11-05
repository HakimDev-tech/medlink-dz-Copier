"use client";
import {useState,type FormEvent} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
type Doctor={id:string;display_name:string;specialty:string;wilaya:string};
export default function HomeVisitForm({doctors}:{doctors:Doctor[]}){
 const [busy,setBusy]=useState(false),[message,setMessage]=useState(""),router=useRouter();
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();const form=e.currentTarget;setBusy(true);setMessage("");
  try{const supabase=createClient();const {data:{user},error:authError}=await supabase.auth.getUser();if(authError)throw authError;if(!user)throw new Error("Reconnectez-vous pour continuer.");
   const f=new FormData(form),when=String(f.get("requested_for")||"");
   const {error}=await supabase.from("home_visit_requests").insert({patient_id:user.id,doctor_id:String(f.get("doctor_id")),wilaya:String(f.get("wilaya")),commune:String(f.get("commune")),address:String(f.get("address")),requested_for:when?new Date(when).toISOString():null,reason:String(f.get("reason")||"")});
   if(error)throw error;setMessage("Votre demande a été transmise au professionnel sélectionné.");form.reset();router.refresh();
  }catch(e){setMessage(e instanceof Error?e.message:"La demande n'a pas pu être envoyée.");}finally{setBusy(false);}
 }
 return <section className="panel" style={{marginTop:16}}><h2>Demander une visite à domicile</h2>
 {doctors.length===0?<p>Aucun professionnel vérifié disponible pour le moment.</p>:<form onSubmit={submit}>
  <div className="input"><label>Professionnel</label><select name="doctor_id" required defaultValue=""><option value="" disabled>Choisir un professionnel</option>{doctors.map(d=><option key={d.id} value={d.id}>{d.display_name} · {d.specialty} · {d.wilaya}</option>)}</select></div>
  <div className="two"><div className="input"><label>Wilaya</label><input name="wilaya" required maxLength={80}/></div><div className="input"><label>Commune</label><input name="commune" required maxLength={80}/></div></div>
  <div className="input"><label>Adresse exacte</label><textarea name="address" required maxLength={500} rows={2}/></div>
  <div className="input"><label>Date et heure souhaitées</label><input type="datetime-local" name="requested_for" min={new Date(Date.now()+10*60*1000-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16)}/></div>
  <div className="input"><label>Motif (facultatif)</label><textarea name="reason" rows={2} maxLength={1000}/></div>
  <button className="btn primary" type="submit" disabled={busy}>{busy?"Transmission…":"Envoyer la demande"}</button>
 </form>}{message&&<div className="notice" role="status">{message}</div>}
 <small style={{color:"var(--muted)"}}>Votre adresse n'est communiquée qu'au professionnel concerné pour traiter cette demande.</small></section>;
}