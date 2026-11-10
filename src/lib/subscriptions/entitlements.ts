import type { SupabaseClient } from "@supabase/supabase-js";
export type SubscriptionFeature="appointments"|"consultations"|"manual_follow_up"|"reminders"|"messaging"|"ai_assistant"|"ai_plan_drafting"|"advanced_follow_up";
const off:Record<SubscriptionFeature,boolean>={appointments:false,consultations:false,manual_follow_up:false,reminders:false,messaging:false,ai_assistant:false,ai_plan_drafting:false,advanced_follow_up:false};
export async function getDoctorEntitlements(db:SupabaseClient,userId:string){
 const {data:d,error:de}=await db.from("doctors").select("id").eq("user_id",userId).maybeSingle();
 if(de||!d)return {planCode:null as string|null,status:null as string|null,periodEnd:null as string|null,features:off};
 const {data:s,error}=await db.from("doctor_subscriptions").select("status,current_period_end,subscription_plans(code,features)").eq("doctor_id",d.id).eq("status","active").gt("current_period_end",new Date().toISOString()).order("created_at",{ascending:false}).limit(1).maybeSingle();
 if(error||!s)return {planCode:null,status:null,periodEnd:null,features:off};
 const p=s.subscription_plans as unknown as {code:string;features:Record<string,boolean>}|null;
 return {planCode:p?.code??null,status:s.status,periodEnd:s.current_period_end,features:{...off,...(p?.features??{})}};
}
export async function doctorHasFeature(db:SupabaseClient,userId:string,feature:SubscriptionFeature){const x=await getDoctorEntitlements(db,userId);return x.features[feature]===true;}
