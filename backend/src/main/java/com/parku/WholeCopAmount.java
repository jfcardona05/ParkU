package com.parku;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;
import java.io.IOException;

/** Money requests must contain integer COP, never silently truncated decimals. */
public class WholeCopAmount extends JsonDeserializer<Long> {
  @Override
  public Long deserialize(JsonParser parser, DeserializationContext context) throws IOException {
    if (!parser.hasToken(JsonToken.VALUE_NUMBER_INT)) {
      return (Long) context.handleUnexpectedToken(Long.class, parser);
    }
    return parser.getLongValue();
  }
}
