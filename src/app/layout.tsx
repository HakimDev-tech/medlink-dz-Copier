import type {Metadata} from "next";
import "./globals.css";
export const metadata:Metadata={
 title:"MedLink DZ — Coordination du parcours de soins",
 description:"Plateforme de coordination entre patients et professionnels de santé en Algérie."
};
export default async function RootLayout({children,params}:{children:React.ReactNode;params?:Promise<{locale?:string}>}){
 const routeParams=params?await params:{};
 const locale=["fr","en","ar"].includes(routeParams.locale||"")?routeParams.locale!:"fr";
 return <html lang={locale} dir={locale==="ar"?"rtl":"ltr"}><body>{children}</body></html>;
}