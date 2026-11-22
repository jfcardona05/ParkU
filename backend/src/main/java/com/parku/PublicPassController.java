package com.parku;

import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

@RestController
public class PublicPassController {
  private final VehicleQrService qr;

  public PublicPassController(VehicleQrService qr) {
    this.qr = qr;
  }

  @GetMapping(value = "/p/{token}", produces = "text/html;charset=UTF-8")
  public ResponseEntity<String> view(@PathVariable String token) {
    int status = 200;
    String content;
    try {
      Map<String, Object> pass = qr.inspectToken(token);
      String type = "moto".equals(pass.get("vehicle_type")) ? "Moto" : "Automóvil";
      content =
          "<span class='badge'>Pase válido</span><h1>"
              + safe(pass.get("plate"))
              + "</h1><dl><dt>Usuario</dt><dd>"
              + safe(pass.get("owner_name"))
              + "</dd><dt>Tipo de vehículo</dt><dd>"
              + type
              + "</dd>"
              + (pass.containsKey("visitor_name")
                  ? "<dt>Concepto</dt><dd>Pase diario visitante · Pagado</dd><dt>Valor"
                      + " recibido</dt><dd>"
                      + safe(pass.get("amount"))
                      + " COP</dd><dt>Válido el día</dt><dd>"
                      + safe(pass.get("service_date"))
                      + " · Colombia</dd><dt>Referencia</dt><dd>"
                      + safe(pass.get("reference"))
                      + "</dd>"
                  : "")
              + "</dl><p class='muted'>Consultar esta ficha no registra un ingreso o una salida."
              + " Portería debe confirmar la operación.</p>";
    } catch (ApiProblem ex) {
      status = ex.status;
      content = "<h1>Pase no disponible</h1><p>" + safe(ex.getMessage()) + "</p>";
    }
    String html =
        """
        <!doctype html><html lang="es"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>ParkU · Pase del vehículo</title>
        <style>
        *{box-sizing:border-box}body{margin:0;background:#f7f7f4;color:#171725;font-family:Manrope,system-ui,sans-serif}
        main{max-width:520px;margin:40px auto;padding:24px}.brand{font-weight:800;font-size:24px;margin-bottom:28px}
        .brand b{display:inline-block;background:#ffdb4d;padding:7px 11px;border-radius:12px;margin-right:8px}
        article{background:white;border-radius:24px;padding:28px;border-top:8px solid #ffdb4d}
        .badge{display:inline-block;background:#eaf5ee;color:#227654;border-radius:16px;padding:10px 14px;font-size:13px}
        h1{font-size:32px;margin:24px 0;overflow-wrap:anywhere}dt{color:#777783;font-size:13px;margin-top:20px}
        dd{margin:6px 0 0;font-size:20px;font-weight:700;overflow-wrap:anywhere}
        .muted{color:#777783;font-size:13px;line-height:1.6;margin-top:28px}
        </style></head><body><main><div class="brand"><b>P</b>ParkU</div><article>
        """
            + content
            + "</article></main></body></html>";
    return ResponseEntity.status(status)
        .header("Cache-Control", "no-store")
        .header("X-Robots-Tag", "noindex, nofollow")
        .header("Referrer-Policy", "no-referrer")
        .header("X-Content-Type-Options", "nosniff")
        .header(
            "Content-Security-Policy",
            "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri"
                + " 'none'")
        .contentType(new MediaType("text", "html", java.nio.charset.StandardCharsets.UTF_8))
        .body(html);
  }

  private String safe(Object text) {
    return HtmlUtils.htmlEscape(String.valueOf(text));
  }
}
