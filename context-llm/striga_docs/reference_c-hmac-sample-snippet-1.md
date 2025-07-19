---
title: C# HMAC Sample Snippet
source_url: https://docs.striga.com/reference/c-hmac-sample-snippet-1
scraped_at: 2025-07-18 17:53:48
---

# C# HMAC Sample Snippet

Below is a simple C# snippet using HttpClient to make a `POST` request to the `/ping` endpoint. Please note that the calculation of the timestamp is the UNIX timestamp in `milliseconds.`

> 📘
>
> ### Calculating HMAC on Striga v1
>
> Please note that from v1 onwards, the root of the URL that includes `/api/v1` is NOT included in the calculation of the HMAC, unlike in v0.

C#

```
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

class Program
{
    static async Task Main()
    {
        string baseUri = "https://www.sandbox.striga.com/api/v1/";
        string SANDBOX_API_SECRET = "<YOUR-API-SECRET>";
        string method = "POST";
        Dictionary<string, string> body = new Dictionary<string, string>
        {
            { "ping", "pong" }
        };
        string TEST_ENDPOINT = "/ping";

        HttpClient client = new HttpClient { BaseAddress = new Uri(baseUri) };

        string auth = CalcSig(body, SANDBOX_API_SECRET, method, TEST_ENDPOINT);

        Dictionary<string, string> headers = new Dictionary<string, string>
        {
            { "authorization", auth },
            { "api-key", "<YOUR-API-KEY>" },
            { "Content-Type", "application/json" }
        };

        Console.WriteLine(PrintHeaders(headers));

        try
        {
            HttpResponseMessage response = await client.PostAsJsonAsync("ping", body, headers);
            string responseBody = await response.Content.ReadAsStringAsync();
            Console.WriteLine(responseBody);
        }
        catch (HttpRequestException e)
        {
            Console.WriteLine(e.ToString());
        }
    }

    static string CalcSig(Dictionary<string, string> body, string SANDBOX_API_SECRET, string method, string TEST_ENDPOINT)
    {
        string mstime = Math.Floor((DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalMilliseconds).ToString();
        string hmac = mstime + method + TEST_ENDPOINT;

        string contentHash = GetContentHash(body);
        hmac += contentHash;

        using (HMACSHA256 hmacSha256 = new HMACSHA256(Encoding.UTF8.GetBytes(SANDBOX_API_SECRET)))
        {
            byte[] hmacBytes = hmacSha256.ComputeHash(Encoding.UTF8.GetBytes(hmac));
            string hmacString = Convert.ToBase64String(hmacBytes);
            string auth = "HMAC " + mstime + ":" + hmacString;
            return auth;
        }
    }

    static string GetContentHash(Dictionary<string, string> body)
    {
        string json = Newtonsoft.Json.JsonConvert.SerializeObject(body);
        using (MD5 md5 = MD5.Create())
        {
            byte[] hashBytes = md5.ComputeHash(Encoding.UTF8.GetBytes(json));
            StringBuilder stringBuilder = new StringBuilder();
            for (int i = 0; i < hashBytes.Length; i++)
            {
                stringBuilder.Append(hashBytes[i].ToString("x2"));
            }
            return stringBuilder.ToString();
        }
    }

    static string PrintHeaders(Dictionary<string, string> headers)
    {
        StringBuilder stringBuilder = new StringBuilder();
        foreach (var header in headers)
        {
            stringBuilder.AppendLine(header.Key + ": " + header.Value);
        }
        return stringBuilder.ToString();
    }
}

```
