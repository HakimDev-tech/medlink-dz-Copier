import {NextResponse} from "next/server";
import {createClient} from "@/lib/supabase/server";
import {answerFromCarePlan,type AgentLocale} from "@/lib/agent/follow-up-agent";
export const runtime="nodejs";
export async function POST(request:Request){
 try{
  const body=await request.json() as {planId?:unknown;message?:unknown;locale?:unknown};
  if(typeof body.planId!=="string"||typeof body.message!=="string"||body.message.trim().length<2||body.message.length>2000)return NextResponse.json({error:"invalid_request"},{status:400});
  const locale:AgentLocale=body.locale==="ar"||body.locale==="en"?body.locale:"fr";
  const supabase=await createClient(),{data:{user},error:authError}=await supabase.auth.getUser();
  if(authError||!user)return NextResponse.json({error:"unauthorized"},{status:401});
  const {data:plan,error:planError}=await supabase.from("follow_up_plans").select("id,doctor_id,patient_id,title,instructions,starts_on,ends_on,status").eq("id",body.planId).eq("status","published").maybeSingle();
  if(planError||!plan)return NextResponse.json({error:"plan_not_found"},{status:404});
  const {data:events}=await supabase.from("follow_up_events").select("event_at,label,instruction").eq("plan_id",plan.id).gte("event_at",new Date().toISOString()).order("event_at",{ascending:true}).limit(50);
  const result=answerFromCarePlan(body.message,{title:plan.title,instructions:plan.instructions,starts_on:plan.starts_on,ends_on:plan.ends_on,events:events??[]},locale);
  await supabase.from("care_agent_runs").insert({plan_id:plan.id,actor_id:user.id,intent:result.intent,outcome:result.outcome,safety_flags:result.safetyFlags});
  return NextResponse.json({answer:result.answer,handoff:result.handoff,intent:result.intent});
 }catch{return NextResponse.json({error:"agent_unavailable"},{status:503});}
}
