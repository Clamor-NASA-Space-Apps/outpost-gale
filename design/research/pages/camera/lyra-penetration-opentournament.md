# Lyra-style penetration avoidance: OpenTournament UR_CameraMode_ThirdPerson (open-source UE game whose camera mode follows Lyra's)
https://github.com/OpenTournament/OpenTournament/blob/master/Source/OpenTournament/Camera/UR_CameraMode_ThirdPerson.h
https://github.com/OpenTournament/OpenTournament/blob/master/Source/OpenTournament/Camera/UR_CameraMode_ThirdPerson.cpp
Fetched 14 Nov 2026 via `gh api` (raw contents), branch master. Lyra's own source could not be reached (Epic sites fail TLS here; Lyra is behind Epic's GitHub org). Header line 1: "// Copyright (c) Open Tournament Games, All Rights Reserved."

## .h
    float PenetrationBlendInTime = 0.1f;
    float PenetrationBlendOutTime = 0.15f;
    /** If true, does collision checks to keep the camera out of the world. */
    bool bPreventPenetration = true;
    /** If true, try to detect nearby walls and move the camera in anticipation.  Helps prevent popping. */
    bool bDoPredictiveAvoidance = true;
    float CollisionPushOutDistance = 2.f;
     * Index: 0  : This is the normal feeler we use to prevent collisions.
     * Index: 1+ : These feelers are used if you bDoPredictiveAvoidance=true, to scan for potential impacts if the player
     *             were to rotate towards that direction and primitively collide the camera so that it pulls in before
     *             impacting the occluder.
    // Curve that defines local-space offsets from the target using the view pitch to evaluate the curve.
    TObjectPtr<const UCurveVector> TargetOffsetCurve;

## .cpp (feelers: rotation, weights, radius, frames between traces)
    PenetrationAvoidanceFeelers.Add(FUR_PenetrationAvoidanceFeeler(FRotator(+00.0f, +00.0f, 0.0f), 1.00f, 1.00f, 14.f, 0));
    PenetrationAvoidanceFeelers.Add(FUR_PenetrationAvoidanceFeeler(FRotator(+00.0f, +16.0f, 0.0f), 0.75f, 0.75f, 00.f, 3));
    PenetrationAvoidanceFeelers.Add(FUR_PenetrationAvoidanceFeeler(FRotator(+00.0f, -16.0f, 0.0f), 0.75f, 0.75f, 00.f, 3));
    PenetrationAvoidanceFeelers.Add(FUR_PenetrationAvoidanceFeeler(FRotator(+00.0f, +32.0f, 0.0f), 0.50f, 0.50f, 00.f, 5));
    PenetrationAvoidanceFeelers.Add(FUR_PenetrationAvoidanceFeeler(FRotator(+00.0f, -32.0f, 0.0f), 0.50f, 0.50f, 00.f, 5));
    PenetrationAvoidanceFeelers.Add(FUR_PenetrationAvoidanceFeeler(FRotator(+20.0f, +00.0f, 0.0f), 1.00f, 1.00f, 00.f, 4));
    PenetrationAvoidanceFeelers.Add(FUR_PenetrationAvoidanceFeeler(FRotator(-20.0f, +00.0f, 0.0f), 0.50f, 0.50f, 00.f, 4));

    if (RayIdx == 0)
    {
        // don't interpolate toward this one, snap to it
        // assumes ray 0 is the center/main ray
        HardBlockedPct = DistBlockedPctThisFrame;
    }
    else
    {
        SoftBlockedPct = DistBlockedPctThisFrame;
    }
    ...
    else if (DistBlockedPct < DistBlockedPctThisFrame)
    {
        // interpolate smoothly out
        if (PenetrationBlendOutTime > DeltaTime)
        {
            DistBlockedPct = DistBlockedPct + DeltaTime / PenetrationBlendOutTime * (DistBlockedPctThisFrame - DistBlockedPct);
    ...
        if (DistBlockedPct > HardBlockedPct)
        {
            DistBlockedPct = HardBlockedPct;
        }
        else if (DistBlockedPct > SoftBlockedPct)
        {
            // interpolate smoothly in
            if (PenetrationBlendInTime > DeltaTime)
            {
                DistBlockedPct = DistBlockedPct - DeltaTime / PenetrationBlendInTime * (DistBlockedPct - SoftBlockedPct);
