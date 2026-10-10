using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class TrackingService(AppDbContext dbContext)
{
    public async Task<WeightRecordResponse[]> GetWeightRecordsAsync(Guid userId, CancellationToken cancellationToken) =>
        await dbContext.WeightRecords.AsNoTracking().Where(record => record.UserId == userId)
            .OrderByDescending(record => record.RecordedAt).ThenByDescending(record => record.CreatedAt)
            .ThenByDescending(record => record.Id)
            .Select(record => new WeightRecordResponse(record.Id, record.WeightKg, record.RecordedAt))
            .ToArrayAsync(cancellationToken);

    public async Task<BodyMeasurementResponse[]> GetBodyMeasurementsAsync(Guid userId, CancellationToken cancellationToken) =>
        await dbContext.BodyMeasurements.AsNoTracking().Where(record => record.UserId == userId)
            .OrderByDescending(record => record.RecordedAt).ThenByDescending(record => record.CreatedAt)
            .ThenByDescending(record => record.Id)
            .Select(record => new BodyMeasurementResponse(record.Id, record.ChestCm, record.WaistCm,
                record.HipCm, record.ArmCm, record.ThighCm, record.BodyFatPercentage, record.RecordedAt))
            .ToArrayAsync(cancellationToken);

    public async Task<WeightRecordResponse> CreateWeightRecordAsync(Guid userId, CreateWeightRecordRequest request,
        CancellationToken cancellationToken)
    {
        var record = new WeightRecord { UserId = userId, WeightKg = request.WeightKg!.Value,
            RecordedAt = request.RecordedAt!.Value.UtcDateTime };
        dbContext.WeightRecords.Add(record);
        await dbContext.SaveChangesAsync(cancellationToken);
        return WeightRecordResponse.FromRecord(record);
    }

    public async Task<BodyMeasurementResponse> CreateBodyMeasurementAsync(Guid userId, CreateBodyMeasurementRequest request,
        CancellationToken cancellationToken)
    {
        var record = new BodyMeasurement { UserId = userId, ChestCm = request.ChestCm, WaistCm = request.WaistCm,
            HipCm = request.HipCm, ArmCm = request.ArmCm, ThighCm = request.ThighCm,
            BodyFatPercentage = request.BodyFatPercentage, RecordedAt = request.RecordedAt!.Value.UtcDateTime };
        dbContext.BodyMeasurements.Add(record);
        await dbContext.SaveChangesAsync(cancellationToken);
        return BodyMeasurementResponse.FromRecord(record);
    }
}
