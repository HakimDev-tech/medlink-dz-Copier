"use client";
import {useEffect,useState} from "react";
import {createClient} from "@/lib/supabase/client";
import {localeTag} from "@/lib/i18n";
type Notice={id:string;title:string;body:string;created_at:string;category?:string;read_at?:string|null};
export default function NotificationFeed({userId,initial,empty}:{userId:string;initial:Notice[];empty:string}){
 const [items,setItems]=useState(initial);
 useEffect(()=>{const supabase=createClient();const channel=supabase.channel("medlink-notifications-"+userId).on("postgres_changes",{event:"INSERT",schema:"public",table:"notifications",filter:"user_id=eq."+userId},payload=>{const row=payload.new as Notice;setItems(old=>old.some(x=>x.id===row.id)?old:[row,...old].slice(0,30));}).subscribe();return()=>{void supabase.removeChannel(channel);};},[userId]);
 return <section className="panel component-stack"><h2>{items.length?"Notifications":"Notifications"}</h2>{items.length===0?<p className="muted">{empty}</p>:items.map(n=><article className="notification-item" key={n.id}><div><strong>{n.title}</strong><p>{n.body}</p><small>{new Date(n.created_at).toLocaleString(localeTag("fr"))}</small></div><span className="notification-dot" aria-label={n.read_at?"Lu":"Non lu"}/></article>)}</section>;
}