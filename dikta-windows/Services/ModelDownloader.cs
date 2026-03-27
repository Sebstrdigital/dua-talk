using System.IO;
using System.Net.Http;

namespace DiktaWindows.Services;

public class ModelDownloader
{
    private static readonly HttpClient _httpClient = new();
    private const string BaseUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/";

    public async Task DownloadModelAsync(string modelName, string destinationPath, IProgress<double>? progress = null)
    {
        var url = $"{BaseUrl}ggml-{modelName}.bin";
        var tmpPath = destinationPath + ".tmp";

        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);

        // Clean up any previous partial download
        if (File.Exists(tmpPath))
            File.Delete(tmpPath);

        using var response = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
        response.EnsureSuccessStatusCode();

        var totalBytes = response.Content.Headers.ContentLength;

        using var stream = await response.Content.ReadAsStreamAsync();
        using (var fileStream = new FileStream(tmpPath, FileMode.Create, FileAccess.Write, FileShare.None, bufferSize: 81920))
        {
            var buffer = new byte[81920];
            long bytesRead = 0;
            int read;

            while ((read = await stream.ReadAsync(buffer)) > 0)
            {
                await fileStream.WriteAsync(buffer.AsMemory(0, read));
                bytesRead += read;

                if (progress != null && totalBytes.HasValue && totalBytes.Value > 0)
                    progress.Report((double)bytesRead / totalBytes.Value);
            }
        }

        // Atomic rename: only promote to .bin after successful completion
        if (File.Exists(destinationPath))
            File.Delete(destinationPath);
        File.Move(tmpPath, destinationPath);
    }
}
