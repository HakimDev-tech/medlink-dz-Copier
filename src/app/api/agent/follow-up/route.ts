import {NextResponse} from "next/server";
import {createClient} from "@/lib/supabase/server";
import {answerFromCarePlan,type AgentLocale} from "@/lib/agent/follow-up-agent";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = await request.json() as { planId?: unknown; message?: unknown; locale?: unknown };
    if (typeof body.planId !== "string" || !/^[0-9a-f-]{36}$/i.test(body.planId)
      || typeof body.message !== "string" || body.message.trim().length < 2 || body.message.length > 2000) {
      return NextResponse.json({error:"invalid_request"}, {status:400});
    }

    const locale: AgentLocale = body.locale === "ar" || body.locale === "en" ? body.locale : "fr";
    const supabase = await createClient();
    const {data:{user}, error:authError} = await supabase.auth.getUser();
    if (authError || !user) return NextResponse.json({error:"unauthorized"}, {status:401});

    const windowStart = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const {count:recentRuns,error:rateError} = await supabase
      .from("care_agent_runs")
      .select("id",{count:"exact",head:true})
      .eq("actor_id",user.id)
      .gte("created_at",windowStart);
    if (rateError) return NextResponse.json({error:"agent_audit_unavailable"},{status:503});
    if ((recentRuns ?? 0) >= 20) return NextResponse.json({error:"rate_limited"},{status:429});

    // This assistant is patient-facing. A doctor must use the professional workspace, not impersonate a patient.
    const {data:plan, error:planError} = await supabase
      .from("follow_up_plans")
      .select("id,doctor_id,patient_id,title,instructions,starts_on,ends_on,status")
      .eq("id",body.planId)
      .eq("patient_id",user.id)
      .eq("status","published")
      .maybeSingle();
    if (planError || !plan) return NextResponse.json({error:"plan_not_found"}, {status:404});

    const {data:entitlement,error:entitlementError}=await supabase.from("doctor_subscriptions").select("id,subscription_plans!inner(code)").eq("doctor_id",plan.doctor_id).eq("status","active").gt("current_period_end",new Date().toISOString()).in("subscription_plans.code",["ai","premium"]).limit(1).maybeSingle();
    if(entitlementError)return NextResponse.json({error:"entitlement_check_unavailable"},{status:503});
    if(!entitlement)return NextResponse.json({error:"assistant_not_included_in_plan"},{status:403});
    const {data:events, error:eventError} = await supabase
      .from("follow_up_events")
      .select("event_at,label,instruction")
      .eq("plan_id",plan.id)
      .gte("event_at",new Date().toISOString())
      .order("event_at",{ascending:true})
      .limit(50);
    if (eventError) return NextResponse.json({error:"plan_context_unavailable"}, {status:503});

    const result = answerFromCarePlan(body.message.trim(), {
      title:plan.title,
      instructions:plan.instructions,
      starts_on:plan.starts_on,
      ends_on:plan.ends_on,
      events:events ?? []
    }, locale);

    // Store only intent/outcome/safety flags; never persist the patient's raw message or medical text.
    const {error:runError} = await supabase.from("care_agent_runs").insert({
      plan_id:plan.id,
      actor_id:user.id,
      intent:result.intent,
      outcome:result.outcome,
      safety_flags:result.safetyFlags
    });
    if (runError) return NextResponse.json({error:"agent_audit_unavailable"}, {status:503});

    return NextResponse.json({
      answer:result.answer,
      handoff:result.handoff,
      intent:result.intent,
      source:result.outcome==="answered_from_plan"?"approved_plan":"safety_policy"
    });
  } catch {
    return NextResponse.json({error:"agent_unavailable"}, {status:503});
  }
}
