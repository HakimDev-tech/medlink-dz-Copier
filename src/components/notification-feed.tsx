"use client";
import {useEffect,useState} from "react";import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";
import {localeTag,tr} from "@/lib/i18n";
type Notice={id:string;title:string;body:string;created_at:string;category?:string;read_at:string|null};
export default function NotificationFeed({userId,initial,empty,locale,title}:{userId:string;initial:Notice[];empty:string;locale:string;title:string}){
 const [items,setItems]=useState(initial),[busyId,setBusyId]=useState<string|null>(null),[error,setError]=useState("");const router=useRouter();
 useEffect(()=>{
  const supabase=createClient();
  const channel=supabase.channel("medlink-notifications-"+userId)
   .on("postgres_changes",{event:"*",schema:"public",table:"notifications",filter:"user_id=eq."+userId},payload=>{
    if(payload.eventType==="INSERT"){
     const row=payload.new as Notice;
     setItems(old=>old.some(x=>x.id===row.id)?old:[row,...old].slice(0,30));router.refresh();
    }else if(payload.eventType==="UPDATE"){
     const row=payload.new as Notice;
     setItems(old=>old.map(x=>x.id===row.id?{...x,...row}:x));
    }
   }).subscribe();
  return()=>{void supabase.removeChannel(channel);};
 },[userId,router]);
 async function markRead(id:string){
  setBusyId(id);setError("");
  try{
   const supabase=createClient();
   const {error}=await supabase.from("notifications").update({read_at:new Date().toISOString()}).eq("id",id).is("read_at",null);
   if(error)throw error;
   setItems(old=>old.map(item=>item.id===id?{...item,read_at:new Date().toISOString()}:item));
  }catch{setError(tr(locale,"notificationUpdateFailed"));}finally{setBusyId(null);}
 }
 return <section className="panel component-stack"><h2>{title}</h2>
  {error&&<p className="form-error" role="alert">{error}</p>}
  {items.length===0?<p className="muted">{empty}</p>:items.map(n=><article className={"notification-item"+(n.read_at?" is-read":" is-unread")} key={n.id}>
   <div className="notification-content"><strong>{n.title}</strong><p>{n.body}</p><small>{new Date(n.created_at).toLocaleString(localeTag(locale))}</small></div>
   <div className="notification-state">
    <span className="notification-dot" aria-label={n.read_at?tr(locale,"notificationRead"):tr(locale,"notificationUnread")}/>
    {n.read_at?<small>{tr(locale,"notificationRead")}</small>:<button className="btn quiet notification-read" type="button" disabled={busyId===n.id} onClick={()=>void markRead(n.id)}>{tr(locale,"markNotificationRead")}</button>}
   </div>
  </article>)}
 </section>;
}
