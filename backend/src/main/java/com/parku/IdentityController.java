package com.parku;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class IdentityController {
  private final IdentityService identity;

  public IdentityController(IdentityService identity) {
    this.identity = identity;
  }

  public record Login(@NotBlank @Email String email, @NotBlank @Size(max = 72) String password) {}

  public record Registration(
      @NotBlank @Size(max = 120) String name,
      @NotBlank @Email @Size(max = 200) String email,
      @NotBlank @Size(min = 6, max = 72) String password,
      String role) {}

  @PostMapping("/login")
  public Map<String, Object> login(@Valid @RequestBody Login body) {
    return identity.login(body.email(), body.password());
  }

  @PostMapping("/register")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> register(@Valid @RequestBody Registration body) {
    return identity.register(body.name(), body.email(), body.password());
  }

  @PostMapping("/logout")
  public Map<String, Object> logout(
      @RequestHeader(value = "Authorization", required = false) String auth) {
    identity.logout(auth);
    return Map.of("success", true);
  }
}
