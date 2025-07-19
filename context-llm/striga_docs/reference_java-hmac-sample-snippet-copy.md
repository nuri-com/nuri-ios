---
title: Java HMAC Sample Snippet
source_url: https://docs.striga.com/reference/java-hmac-sample-snippet-copy
scraped_at: 2025-07-18 17:50:17
---

# Java HMAC Sample Snippet

Below is a simple Java snippet using HttpClient to make a `POST` request to the`ping\` endpoint. Please note that the calculation of the timestamp is the UNIX timestamp in `milliseconds.`

> 📘
>
> ### Calculating HMAC on Striga v1
>
> Please note that from v1 onwards, the root of the URL that includes `/api/v1` is NOT included in the calculation of the HMAC, unlike in v0.

Java

```
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class Main {
    public static void main(String[] args) throws NoSuchAlgorithmException, IOException {
        String baseUri = "https://www.sandbox.striga.com/api/v1/";
        String sandboxApiSecret = "<YOUR-API-SECRET>";
        String method = "POST";
        Map<String, String> body = new HashMap<>();
        body.put("ping", "pong");
        String testEndpoint = "/ping";

        OkHttpClient client = new OkHttpClient.Builder().build();

        String auth = calcSig(body, sandboxApiSecret, method, testEndpoint);

        Map<String, String> headers = new HashMap<>();
        headers.put("Authorization", auth);
        headers.put("Api-Key", "<YOUR-API-KEY>");
        headers.put("Content-Type", "application/json");

        System.out.println(printHeaders(headers));

        MediaType mediaType = MediaType.parse("application/json; charset=utf-8");
        RequestBody requestBody = RequestBody.create(mediaType, gson.toJson(body));
        Request request = new Request.Builder()
                .url(baseUri + "ping")
                .headers(okhttp3.Headers.of(headers))
                .post(requestBody)
                .build();

        try (Response response = client.newCall(request).execute()) {
            System.out.println(response.body().string());
        }
    }

    static String calcSig(Map<String, String> body, String sandboxApiSecret, String method, String testEndpoint)
            throws NoSuchAlgorithmException {
        long mstime = Instant.now().toEpochMilli();
        String hmac = mstime + method + testEndpoint;

        String contentHash = getContentHash(body);
        hmac += contentHash;

        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hmacBytes = digest.digest(hmac.getBytes());

        String hmacString = Base64.getEncoder().encodeToString(hmacBytes);
        String auth = "HMAC " + mstime + ":" + hmacString;
        return auth;
    }

    static String getContentHash(Map<String, String> body) throws NoSuchAlgorithmException {
        StringBuilder json = new StringBuilder();
        for (Map.Entry<String, String> entry : body.entrySet()) {
            json.append('"').append(entry.getKey()).append("\":\"").append(entry.getValue()).append("\",");
        }
        if (json.length() > 0) {
            json.deleteCharAt(json.length() - 1);
        }

        MessageDigest digest = MessageDigest.getInstance("MD5");
        byte[] hashBytes = digest.digest(json.toString().getBytes());

        StringBuilder stringBuilder = new StringBuilder();
        for (byte hashByte : hashBytes) {
            stringBuilder.append(String.format("%02x", hashByte));
        }
        return stringBuilder.toString();
    }

    static String printHeaders(Map<String, String> headers) {
        StringBuilder stringBuilder = new StringBuilder();
        for (Map.Entry<String, String> entry : headers.entrySet()) {
            stringBuilder.append(entry.getKey()).append(": ").append(entry.getValue()).append("\n");
        }
        return stringBuilder.toString();
    }
}

```
