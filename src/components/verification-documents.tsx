"use client";
import {useState,type FormEvent} from "react";
import {createClient} from "@/lib/supabase/client";
import {localeTag,tr} from "@/lib/i18n";
type Doc={id:string;document_type:string;original_filename:string;status:string;review_note:string|null;created_at:string};
export default function VerificationDocuments({doctorId,userId,initialDocuments,locale}:{doctorId:string;userId:string;initialDocuments:Doc[];locale:string}){
 const [docs,setDocs]=useState(initialDocuments),[busy,setBusy]=useState(false),[message,setMessage]=useState("");
 async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage("");const form=e.currentTarget,values=new FormData(form),file=values.get("file");
  try{if(!(file instanceof File)||file.size===0)throw new Error(tr(locale,"selectFile"));if(file.size>10*1024*1024)throw new Error(tr(locale,"fileTooLarge"));if(!["application/pdf","image/jpeg","image/png"].includes(file.type))throw new Error(tr(locale,"fileTypes"));
   const type=String(values.get("document_type")),ext=file.name.split(".").pop()?.toLowerCase()||"bin",path=userId+"/"+doctorId+"/"+crypto.randomUUID()+"."+ext,supabase=createClient();
   const {error:uploadError}=await supabase.storage.from("doctor-verification").upload(path,file,{contentType:file.type,upsert:false});if(uploadError)throw uploadError;
   const {data,error:insertError}=await supabase.from("doctor_verification_documents").insert({doctor_id:doctorId,uploaded_by:userId,document_type:type,object_path:path,original_filename:file.name,mime_type:file.type,size_bytes:file.size}).select("id,document_type,original_filename,status,review_note,created_at").single();
   if(insertError){await supabase.storage.from("doctor-verification").remove([path]);throw insertError;}setDocs(old=>[...old,data as Doc]);form.reset();setMessage(tr(locale,"uploadSuccess"));
  }catch(e){const msg=e instanceof Error?e.message:"";setMessage([tr(locale,"selectFile"),tr(locale,"fileTooLarge"),tr(locale,"fileTypes")].includes(msg)?msg:tr(locale,"uploadFailed"));}
  finally{setBusy(false);}
 }
 const types:Record<string,string>={professional_card:tr(locale,"professionalCard"),license:tr(locale,"license"),diploma:tr(locale,"diploma")};
 return <section className="panel component-stack"><h2>{tr(locale,"professionalDocuments")}</h2><p className="muted">{tr(locale,"documentsHelp")}</p>
 <form onSubmit={submit} className="form-stack"><div className="input"><label>{tr(locale,"documentType")}</label><select name="document_type" required defaultValue="professional_card"><option value="professional_card">{types.professional_card}</option><option value="license">{types.license}</option><option value="diploma">{types.diploma}</option></select></div>
 <div className="input"><label>{tr(locale,"file")}</label><input type="file" name="file" accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png" required/></div><button className="btn primary" type="submit" disabled={busy}>{busy?tr(locale,"uploading"):tr(locale,"upload")}</button></form>
 {message&&<div className="notice" role="status">{message}</div>}
 <div className="component-stack">{docs.length===0?<p className="muted">{tr(locale,"noDocuments")}</p>:docs.map(d=><div className="row" key={d.id}><div><strong>{d.original_filename}</strong><small>{types[d.document_type]||d.document_type} · {new Date(d.created_at).toLocaleDateString(localeTag(locale))}</small>{d.review_note&&<small>{d.review_note}</small>}</div><span className="tag">{d.status}</span></div>)}</div></section>;
}